-- ============================================================
-- ClubOS — Meetings
--
-- A meeting is a scheduled reminder (not a Zoom/Teams replacement):
-- the scheduler picks who's invited, everyone invited is notified
-- immediately, and optionally again a chosen amount of time before
-- the meeting starts. Meetings can be one-off or recur daily,
-- weekly, bi-weekly, or monthly.
--
-- Who can schedule for whom:
--   President : VPs, VPs & Directors, or a custom pick of anyone
--   VP        : VPs (& President), their own directors + themselves,
--               or a custom pick limited to that same circle
--
-- Invitees are snapshotted into meeting_attendees at creation time
-- (same pattern as poll_eligible_voters); visibility and reminders
-- key off that list. Reminders and recurrence rolling are driven by
-- pg_cron calling process_meetings_due() every 5 minutes — the
-- inserted notification rows ride the existing DB-webhook →
-- send-push-notification pipeline.
-- ============================================================

-- 1. Tables ---------------------------------------------------

create table if not exists public.meetings (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null,
  notes text,
  created_by uuid not null references public.profiles(id),
  audience text not null
    check (audience in ('vps', 'vps_directors', 'my_directors', 'custom')),
  scheduled_at timestamptz not null,        -- next (or only) occurrence
  recurrence text not null default 'once'
    check (recurrence in ('once', 'daily', 'weekly', 'biweekly', 'monthly')),
  reminder_offset_minutes int
    check (reminder_offset_minutes is null or reminder_offset_minutes > 0),
  reminder_sent boolean not null default false,  -- for the CURRENT occurrence
  created_at timestamptz default now()
);

create table if not exists public.meeting_attendees (
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (meeting_id, user_id)
);

create index if not exists meetings_club_id_idx on public.meetings (club_id);
create index if not exists meetings_due_idx on public.meetings (scheduled_at);
create index if not exists meeting_attendees_user_id_idx
  on public.meeting_attendees (user_id);

alter table public.meetings enable row level security;
alter table public.meeting_attendees enable row level security;

grant select, insert, update, delete on public.meetings to authenticated;
grant select, insert, delete on public.meeting_attendees to authenticated;

-- 2. SECURITY DEFINER helpers (avoid cross-table policy recursion,
--    same pattern as is_poll_creator / am_i_eligible_voter) --------

create or replace function public.is_meeting_creator(p_meeting_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from meetings where id = p_meeting_id and created_by = auth.uid()
  );
$$;

create or replace function public.am_i_meeting_attendee(p_meeting_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from meeting_attendees
    where meeting_id = p_meeting_id and user_id = auth.uid()
  );
$$;

-- Role-scope check for inviting: presidents may invite any approved
-- member; VPs may invite the president, fellow VPs, their own
-- directors, and themselves. Directors can't create meetings at all
-- (enforced by meetings_insert), so they never reach this check.
create or replace function public.can_add_meeting_attendee(
  p_meeting_id uuid, p_user_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1
    from meetings m
    join user_club_roles me
      on me.club_id = m.club_id and me.user_id = auth.uid()
     and me.status = 'approved'
    join user_club_roles tgt
      on tgt.club_id = m.club_id and tgt.user_id = p_user_id
     and tgt.status = 'approved'
    where m.id = p_meeting_id
      and m.created_by = auth.uid()
      and (
        me.role = 'president'
        or (me.role = 'vice_president'
            and (tgt.user_id = auth.uid()
                 or tgt.role in ('president', 'vice_president')
                 or (tgt.role = 'director' and tgt.reports_to = auth.uid())))
      )
  );
$$;

revoke execute on function public.is_meeting_creator(uuid) from public, anon;
revoke execute on function public.am_i_meeting_attendee(uuid) from public, anon;
revoke execute on function public.can_add_meeting_attendee(uuid, uuid)
  from public, anon;
grant execute on function public.is_meeting_creator(uuid) to authenticated;
grant execute on function public.am_i_meeting_attendee(uuid) to authenticated;
grant execute on function public.can_add_meeting_attendee(uuid, uuid)
  to authenticated;

-- 3. Policies -------------------------------------------------

drop policy if exists "meetings_select" on public.meetings;
create policy "meetings_select" on public.meetings
  for select to authenticated using (
    created_by = auth.uid() or public.am_i_meeting_attendee(id)
  );

drop policy if exists "meetings_insert" on public.meetings;
create policy "meetings_insert" on public.meetings
  for insert to authenticated with check (
    created_by = auth.uid()
    and scheduled_at > now()
    and exists (
      select 1 from public.user_club_roles ucr
      where ucr.club_id = meetings.club_id
        and ucr.user_id = auth.uid()
        and ucr.status = 'approved'
        and ucr.role in ('president', 'vice_president')
    )
  );

drop policy if exists "meetings_update" on public.meetings;
create policy "meetings_update" on public.meetings
  for update to authenticated using (created_by = auth.uid());

drop policy if exists "meetings_delete" on public.meetings;
create policy "meetings_delete" on public.meetings
  for delete to authenticated using (created_by = auth.uid());

drop policy if exists "ma_select" on public.meeting_attendees;
create policy "ma_select" on public.meeting_attendees
  for select to authenticated using (
    user_id = auth.uid() or public.is_meeting_creator(meeting_id)
  );

drop policy if exists "ma_insert" on public.meeting_attendees;
create policy "ma_insert" on public.meeting_attendees
  for insert to authenticated with check (
    public.can_add_meeting_attendee(meeting_id, user_id)
  );

drop policy if exists "ma_delete" on public.meeting_attendees;
create policy "ma_delete" on public.meeting_attendees
  for delete to authenticated using (
    public.is_meeting_creator(meeting_id)
  );

-- 4. Notify invitees the moment they're added -----------------
-- The app inserts the meeting, then the attendee snapshot; this
-- per-row trigger notifies everyone except the scheduler.

create or replace function public.notify_on_meeting_invite()
returns trigger language plpgsql security definer
set search_path = public as $$
declare
  v_meeting record;
begin
  select club_id, title, created_by into v_meeting
  from meetings where id = new.meeting_id;

  if new.user_id <> v_meeting.created_by then
    insert into public.notifications (user_id, club_id, type, message)
    values (new.user_id, v_meeting.club_id, 'meeting_scheduled',
            'You were invited to a meeting: ' || v_meeting.title);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_meeting_invite on public.meeting_attendees;
create trigger trg_notify_meeting_invite
  after insert on public.meeting_attendees
  for each row execute function public.notify_on_meeting_invite();

-- 5. Notify attendees when a future meeting is cancelled ------
-- BEFORE DELETE so the attendee list is still readable. Guarded so
-- cascades (e.g. club deletion) can never make the delete fail.

create or replace function public.notify_on_meeting_cancelled()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  begin
    if old.scheduled_at > now() then
      insert into public.notifications (user_id, club_id, type, message)
      select ma.user_id, old.club_id, 'meeting_cancelled',
             'Meeting cancelled: ' || old.title
      from meeting_attendees ma
      where ma.meeting_id = old.id
        and ma.user_id <> old.created_by;
    end if;
  exception when others then
    null;
  end;
  return old;
end;
$$;

drop trigger if exists trg_notify_meeting_cancelled on public.meetings;
create trigger trg_notify_meeting_cancelled
  before delete on public.meetings
  for each row execute function public.notify_on_meeting_cancelled();

-- 6. Activity log on scheduling (same conventions as polls) ---

create or replace function public.log_meeting_scheduled()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id, new.created_by, 'meeting_scheduled',
      jsonb_build_object('title', new.title, 'meeting_id', new.id,
                         'scheduled_at', new.scheduled_at,
                         'recurrence', new.recurrence)
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists trg_log_meeting_scheduled on public.meetings;
create trigger trg_log_meeting_scheduled
  after insert on public.meetings
  for each row execute function public.log_meeting_scheduled();

-- 7. Cron worker: due reminders + rolling recurring meetings --
-- Runs every 5 minutes. Reminder messages use RELATIVE time ("in
-- about 2 hours") so we never have to know the club's timezone.

create or replace function public.process_meetings_due()
returns void language plpgsql security definer
set search_path = public as $$
declare
  r record;
  v_next timestamptz;
  v_step interval;
begin
  -- (a) send due reminders for the current occurrence
  insert into public.notifications (user_id, club_id, type, message)
  select ma.user_id, m.club_id, 'meeting_reminder',
         'Reminder: ' || m.title || ' starts ' ||
         case
           when m.scheduled_at - now() >= interval '90 minutes' then
             'in about ' ||
             round(extract(epoch from m.scheduled_at - now()) / 3600.0)::int
             || ' hours'
           else
             'in ' ||
             greatest(1,
               round(extract(epoch from m.scheduled_at - now()) / 60.0)::int)
             || ' minutes'
         end
  from meetings m
  join meeting_attendees ma on ma.meeting_id = m.id
  where m.reminder_offset_minutes is not null
    and not m.reminder_sent
    and m.scheduled_at > now()
    and m.scheduled_at
        - make_interval(mins => m.reminder_offset_minutes) <= now();

  update meetings m
  set reminder_sent = true
  where m.reminder_offset_minutes is not null
    and not m.reminder_sent
    and m.scheduled_at > now()
    and m.scheduled_at
        - make_interval(mins => m.reminder_offset_minutes) <= now();

  -- (b) roll recurring meetings to their next occurrence, one hour
  -- after start so an in-progress meeting stays visible. The while
  -- loop catches up cleanly even if the project was paused past
  -- several occurrences.
  for r in
    select id, scheduled_at, recurrence from meetings
    where recurrence <> 'once'
      and scheduled_at <= now() - interval '1 hour'
  loop
    v_step := case r.recurrence
      when 'daily'    then interval '1 day'
      when 'weekly'   then interval '7 days'
      when 'biweekly' then interval '14 days'
      when 'monthly'  then interval '1 month'
    end;
    v_next := r.scheduled_at;
    while v_next <= now() loop
      v_next := v_next + v_step;
    end loop;
    update meetings
    set scheduled_at = v_next, reminder_sent = false
    where id = r.id;
  end loop;
end;
$$;

revoke execute on function public.process_meetings_due() from public, anon,
  authenticated;

-- 8. Schedule it ----------------------------------------------

create extension if not exists pg_cron;

select cron.schedule(
  'process-meetings-due',
  '*/5 * * * *',
  $$select public.process_meetings_due()$$
);
