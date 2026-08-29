-- ============================================================
-- ClubOS — Start a New Term
--
-- University clubs turn over every year: a new president, new VPs,
-- new directors. Last year's tasks, events, announcements, polls and
-- meetings do not carry over. reset_club_term() wipes the club's
-- operational content so the incoming board starts on a clean slate,
-- while keeping the things that DO carry over: the club itself, its
-- name, its constitution, and the president running the reset.
--
-- Deliberately a hard delete rather than an archive flag: an
-- `archived_at` column would have to be filtered in every query and
-- RLS policy across tasks, events, polls, announcements and
-- meetings, and missing one leaks last year's content into the new
-- board's view. The ceremony guarding it lives in the UI.
--
-- Attachment FILES are not touched here. Deleting a storage.objects
-- row would strip the metadata while leaving the blob behind, so the
-- app clears them through the Storage API *before* calling this
-- function; the policy below is what lets a president do that.
-- ============================================================

-- ── 1. Presidents can delete their club's attachment files ────
-- The original policy allowed only the uploader (owner = auth.uid()),
-- so files belonging to a deleted task could never be reclaimed by
-- anyone. Scope it like the read/upload policies (20260627000001):
-- the uploader, or the president of the task's club.

drop policy if exists "Users can delete their own task attachments"
  on storage.objects;
drop policy if exists "Uploader or club president can delete task attachments"
  on storage.objects;

create policy "Uploader or club president can delete task attachments"
on storage.objects for delete to authenticated
using (
  bucket_id = 'task-attachments'
  and (
    owner = auth.uid()
    or exists (
      select 1 from public.tasks t
      join public.user_club_roles ucr on ucr.club_id = t.club_id
      where t.id = (storage.foldername(name))[1]::uuid
        and ucr.user_id = auth.uid()
        and ucr.role = 'president'
        and ucr.status = 'approved'
    )
  )
);

-- ── 2. reset_club_term() ──────────────────────────────────────

-- Returns the storage paths of the attachments it just orphaned, so
-- the caller can delete the actual files through the Storage API.
-- Deleting storage.objects rows here would drop the metadata and
-- strand the blobs, so the files are the app's job — and collecting
-- the paths inside the same transaction that removes the rows means
-- the list can never drift from what was deleted.
drop function if exists public.reset_club_term(uuid, boolean);

create function public.reset_club_term(
  p_club_id uuid,
  p_clear_roster boolean default false
)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_club_name text;
  v_paths text[] := '{}';
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  if not exists (
    select 1 from user_club_roles
    where club_id = p_club_id and user_id = v_uid
      and role = 'president' and status = 'approved'
  ) then
    raise exception 'Only the club president can start a new term.';
  end if;

  select name into v_club_name from clubs where id = p_club_id;

  -- Legacy rows stored a full URL rather than a path; those are not
  -- addressable through the Storage API, so skip them.
  select coalesce(array_agg(ta.file_url), '{}') into v_paths
  from task_attachments ta
  join tasks t on t.id = ta.task_id
  where t.club_id = p_club_id
    and ta.file_url is not null
    and ta.file_url not like 'http%';

  -- Operational content. Children cascade: task_comments and
  -- task_attachments from tasks, event_rsvps from events,
  -- poll_options/poll_votes/poll_eligible_voters from polls,
  -- meeting_attendees from meetings.
  delete from tasks         where club_id = p_club_id;
  delete from events        where club_id = p_club_id;
  delete from announcements where club_id = p_club_id;
  delete from polls         where club_id = p_club_id;
  delete from meetings      where club_id = p_club_id;
  delete from activity_log  where club_id = p_club_id;
  delete from notifications where club_id = p_club_id;

  -- Optionally clear the roster for a full board handover. Every
  -- membership row for the club goes except the president's —
  -- approved, pending, rejected and 'left' alike. Nothing references
  -- these members any more (the content above is gone), so unlike
  -- leave_club() there is no name-rendering reason to keep them.
  if p_clear_roster then
    delete from user_club_roles
    where club_id = p_club_id and user_id <> v_uid;
  end if;

  -- Open the fresh log with the reason it is empty.
  insert into activity_log (club_id, user_id, action_type, details)
  values (
    p_club_id, v_uid, 'term_started',
    jsonb_build_object('cleared_roster', p_clear_roster)
  );

  -- Tell whoever is still here why the club looks empty. (With the
  -- roster cleared there is nobody left to tell.)
  if not p_clear_roster then
    insert into notifications (user_id, club_id, type, message)
    select ucr.user_id, p_club_id, 'term_started',
           'A new term has started in '
             || coalesce(v_club_name, 'your club')
             || '. Tasks, events, announcements, polls and meetings '
             || 'from the previous term have been cleared.'
    from user_club_roles ucr
    where ucr.club_id = p_club_id
      and ucr.status = 'approved'
      and ucr.user_id <> v_uid;
  end if;

  return v_paths;
end;
$$;

revoke execute on function public.reset_club_term(uuid, boolean)
  from public, anon;
grant execute on function public.reset_club_term(uuid, boolean)
  to authenticated;
