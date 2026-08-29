-- ============================================================
-- ClubOS — Remove task file attachments
--
-- Product decision: clubs already share files through WhatsApp and
-- Teams, and hosting them in ClubOS bought storage quota, RLS
-- surface and orphaned-blob problems for little benefit. Tasks keep
-- their title, description, due date, urgency and comments.
--
-- Verified empty before dropping: 0 rows in task_attachments and 0
-- objects in the bucket, so no user data is lost here.
--
-- Removing this also drops the file_picker dependency, which is what
-- pulled the photo-library and camera frameworks into the iOS build —
-- so the App Store submission no longer needs
-- NSPhotoLibraryUsageDescription / NSCameraUsageDescription.
-- ============================================================

-- 1. Storage policies (all three generations of the delete policy,
--    plus the read/upload pair from 20260627000001).
drop policy if exists "Users can delete their own task attachments"
  on storage.objects;
drop policy if exists "Uploader or club president can delete task attachments"
  on storage.objects;
drop policy if exists "Uploader or task deleter can delete task attachments"
  on storage.objects;
drop policy if exists "Club members can upload task attachments"
  on storage.objects;
drop policy if exists "Club members can read task attachments"
  on storage.objects;
drop policy if exists "Authenticated users can upload task attachments"
  on storage.objects;
drop policy if exists "Authenticated users can read task attachments"
  on storage.objects;

-- 2. The bucket row itself is NOT dropped here: Supabase's
--    protect_delete() trigger rejects direct SQL deletes on the
--    storage tables. With every policy above gone and RLS enabled,
--    the bucket is inert — no authenticated user can read or write
--    it. Delete it from the Supabase dashboard (Storage → Buckets)
--    to tidy up.

-- 3. The table.
drop table if exists public.task_attachments;

-- 4. reset_club_term() no longer has files to hand back, so it goes
--    back to returning void.
drop function if exists public.reset_club_term(uuid, boolean);

create function public.reset_club_term(
  p_club_id uuid,
  p_clear_roster boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_club_name text;
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

  -- Children cascade: task_comments from tasks, event_rsvps from
  -- events, poll_options/poll_votes/poll_eligible_voters from polls,
  -- meeting_attendees from meetings.
  delete from tasks         where club_id = p_club_id;
  delete from events        where club_id = p_club_id;
  delete from announcements where club_id = p_club_id;
  delete from polls         where club_id = p_club_id;
  delete from meetings      where club_id = p_club_id;
  delete from activity_log  where club_id = p_club_id;
  delete from notifications where club_id = p_club_id;

  if p_clear_roster then
    delete from user_club_roles
    where club_id = p_club_id and user_id <> v_uid;
  end if;

  insert into activity_log (club_id, user_id, action_type, details)
  values (
    p_club_id, v_uid, 'term_started',
    jsonb_build_object('cleared_roster', p_clear_roster)
  );

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
end;
$$;

revoke execute on function public.reset_club_term(uuid, boolean)
  from public, anon;
grant execute on function public.reset_club_term(uuid, boolean)
  to authenticated;
