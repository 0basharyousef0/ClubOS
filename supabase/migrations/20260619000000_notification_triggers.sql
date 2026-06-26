-- Phase 8: auto-create in-app notifications on key events.
-- All functions are SECURITY DEFINER so they can insert rows for OTHER users
-- (the recipients) regardless of the acting user's RLS scope.

-- ── Task assigned ─────────────────────────────────────────────
create or replace function public.notify_on_task_assigned()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.assigned_to is not null
     and (new.assigned_by is null or new.assigned_to <> new.assigned_by) then
    insert into public.notifications (user_id, club_id, type, message)
    values (new.assigned_to, new.club_id, 'task_assigned',
            'You were assigned a task: ' || new.title);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_task_assigned on public.tasks;
create trigger trg_notify_task_assigned
  after insert on public.tasks
  for each row execute function public.notify_on_task_assigned();

-- ── Event posted ──────────────────────────────────────────────
create or replace function public.notify_on_event_posted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, club_id, type, message)
  select ucr.user_id, new.club_id, 'event_posted', 'New event: ' || new.title
  from public.user_club_roles ucr
  where ucr.club_id = new.club_id
    and ucr.status = 'approved'
    and ucr.user_id <> new.created_by;
  return new;
end;
$$;

drop trigger if exists trg_notify_event_posted on public.events;
create trigger trg_notify_event_posted
  after insert on public.events
  for each row execute function public.notify_on_event_posted();

-- ── Announcement posted ───────────────────────────────────────
create or replace function public.notify_on_announcement_posted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, club_id, type, message)
  select ucr.user_id, new.club_id, 'announcement',
         'New announcement: ' || new.title
  from public.user_club_roles ucr
  where ucr.club_id = new.club_id
    and ucr.status = 'approved'
    and ucr.user_id <> new.posted_by;
  return new;
end;
$$;

drop trigger if exists trg_notify_announcement_posted on public.announcements;
create trigger trg_notify_announcement_posted
  after insert on public.announcements
  for each row execute function public.notify_on_announcement_posted();

-- ── Membership approved ───────────────────────────────────────
-- Fires only when status transitions INTO 'approved' (so a president
-- self-approving at club creation, which is an INSERT, never self-notifies).
create or replace function public.notify_on_membership_approved()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_club_name text;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    select name into v_club_name from public.clubs where id = new.club_id;
    insert into public.notifications (user_id, club_id, type, message)
    values (new.user_id, new.club_id, 'membership_approved',
            'Your membership in ' || coalesce(v_club_name, 'the club') ||
            ' was approved');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_membership_approved on public.user_club_roles;
create trigger trg_notify_membership_approved
  after update on public.user_club_roles
  for each row execute function public.notify_on_membership_approved();
