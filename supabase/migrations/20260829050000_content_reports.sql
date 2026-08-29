-- ============================================================
-- ClubOS — Reporting objectionable content
--
-- App Store guideline 1.2 requires an app carrying user-generated
-- content to provide a way to report objectionable content, and a
-- means of removing the person who posted it. The club president
-- already has both removal powers (delete the content, remove the
-- member); this adds the reporting half.
--
-- A report notifies every approved president of the club. The
-- president reviews it and acts using the tools they already have —
-- there is deliberately no separate moderation queue to maintain.
-- ============================================================

create table if not exists public.content_reports (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null
    check (content_type in ('announcement', 'task_comment')),
  -- Not a foreign key on purpose: the reported row is often deleted as
  -- the resolution, and the report should survive as a record of it.
  content_id uuid not null,
  content_excerpt text,
  reason text,
  created_at timestamptz default now()
);

create index if not exists content_reports_club_id_idx
  on public.content_reports (club_id, created_at desc);

alter table public.content_reports enable row level security;

grant select, insert on public.content_reports to authenticated;

-- Any approved member of the club may file a report, as themselves.
drop policy if exists "content_reports_insert" on public.content_reports;
create policy "content_reports_insert" on public.content_reports
  for insert to authenticated with check (
    reporter_id = auth.uid()
    and exists (
      select 1 from public.user_club_roles ucr
      where ucr.club_id = content_reports.club_id
        and ucr.user_id = auth.uid()
        and ucr.status = 'approved'
    )
  );

-- Visible to the person who filed it and to the club president.
drop policy if exists "content_reports_select" on public.content_reports;
create policy "content_reports_select" on public.content_reports
  for select to authenticated using (
    reporter_id = auth.uid() or public.is_my_club_president(club_id)
  );

-- ── Notify the president ──────────────────────────────────────
-- Reporter stays anonymous in the message: naming them invites
-- retaliation inside a small club, and the president can see the
-- reporter on the report row itself if they need to.

create or replace function public.notify_on_content_report()
returns trigger language plpgsql security definer
set search_path = public as $$
declare
  v_label text;
begin
  v_label := case new.content_type
    when 'announcement' then 'an announcement'
    when 'task_comment' then 'a task comment'
    else 'content'
  end;

  insert into public.notifications (user_id, club_id, type, message)
  select p.user_id, new.club_id, 'content_reported',
         'A member reported ' || v_label ||
         case
           when coalesce(trim(new.content_excerpt), '') <> '' then
             ': "' || left(trim(new.content_excerpt), 80) || '"'
           else ''
         end
  from user_club_roles p
  where p.club_id = new.club_id
    and p.role = 'president'
    and p.status = 'approved';

  return new;
end;
$$;

drop trigger if exists trg_notify_content_report on public.content_reports;
create trigger trg_notify_content_report
  after insert on public.content_reports
  for each row execute function public.notify_on_content_report();

-- Logged for the president's activity log so a report is visible even
-- if the notification is dismissed. Guarded: a failure here must never
-- block someone from filing a report.
create or replace function public.log_content_report()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id, new.reporter_id, 'content_reported',
      jsonb_build_object('content_type', new.content_type,
                         'content_id', new.content_id)
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists trg_log_content_report on public.content_reports;
create trigger trg_log_content_report
  after insert on public.content_reports
  for each row execute function public.log_content_report();
