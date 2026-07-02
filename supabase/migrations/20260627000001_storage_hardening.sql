-- ============================================================
-- ClubOS — Storage Bucket Security Hardening
-- Addresses: HIGH-01
-- ============================================================

-- Make the bucket private. Public buckets bypass SELECT RLS
-- entirely — anyone with an object URL can download without auth.
update storage.buckets
set public = false
where id = 'task-attachments';

-- Drop old unrestricted upload policy (any authenticated user
-- could write to any path, enabling cross-club access).
drop policy if exists "Authenticated users can upload task attachments"
  on storage.objects;

-- New upload policy: object path must start with the task's id
-- (format: "{task_id}/{epoch}_{filename}"), and the caller must
-- be an approved member of the task's club.
create policy "Club members can upload task attachments"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'task-attachments'
  and exists (
    select 1 from public.tasks t
    join public.user_club_roles ucr on ucr.club_id = t.club_id
    where t.id = (storage.foldername(name))[1]::uuid
      and ucr.user_id = auth.uid()
      and ucr.status = 'approved'
  )
);

-- Drop old broad read policy and replace with membership-scoped one.
drop policy if exists "Authenticated users can read task attachments"
  on storage.objects;

create policy "Club members can read task attachments"
on storage.objects for select to authenticated
using (
  bucket_id = 'task-attachments'
  and exists (
    select 1 from public.tasks t
    join public.user_club_roles ucr on ucr.club_id = t.club_id
    where t.id = (storage.foldername(name))[1]::uuid
      and ucr.user_id = auth.uid()
      and ucr.status = 'approved'
  )
);
