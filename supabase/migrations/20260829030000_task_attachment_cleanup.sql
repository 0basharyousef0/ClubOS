-- ============================================================
-- ClubOS — Let attachment files be cleaned up with their task
--
-- Deleting a task cascades its task_attachments ROWS but never
-- touched the files in storage, and the delete policy only allowed
-- the original uploader — so a file on a deleted task could not be
-- reclaimed by anyone and sat in the bucket forever.
--
-- 20260829020000 widened that to the club president for the term
-- reset. Widen it once more to match tasks_delete exactly
-- (assigned_by = auth.uid() OR club president): whoever is allowed
-- to delete the task is allowed to delete the files hanging off it,
-- so a VP deleting their own task can clear a director's upload.
-- ============================================================

drop policy if exists "Users can delete their own task attachments"
  on storage.objects;
drop policy if exists "Uploader or club president can delete task attachments"
  on storage.objects;
drop policy if exists "Uploader or task deleter can delete task attachments"
  on storage.objects;

create policy "Uploader or task deleter can delete task attachments"
on storage.objects for delete to authenticated
using (
  bucket_id = 'task-attachments'
  and (
    owner = auth.uid()
    or exists (
      select 1 from public.tasks t
      where t.id = (storage.foldername(name))[1]::uuid
        and (
          t.assigned_by = auth.uid()
          or public.is_my_club_president(t.club_id)
        )
    )
  )
);
