-- ============================================================
-- ClubOS — Task visibility: your own tasks only, president oversight
--
-- Product rule: VPs and directors only ever see tasks assigned TO
-- them (plus, at the data layer, tasks they assigned — needed so the
-- assigner's own task-detail links keep working). Only the club
-- president has club-wide task visibility; their oversight views are
-- "tasks I assigned" plus the activity log, which now also records
-- every assignment via a new trigger.
-- ============================================================

-- SELECT: assignee, assigner, or president. Previously any approved
-- club member could read every club task.
drop policy if exists "tasks_select" on public.tasks;
create policy "tasks_select" on public.tasks
  for select to authenticated using (
    assigned_to = auth.uid()
    or assigned_by = auth.uid()
    or public.is_my_club_president(tasks.club_id)
  );

-- UPDATE: same circle. Previously ANY VP could update ANY club task.
drop policy if exists "tasks_update" on public.tasks;
create policy "tasks_update" on public.tasks
  for update to authenticated using (
    assigned_to = auth.uid()
    or assigned_by = auth.uid()
    or public.is_my_club_president(tasks.club_id)
  );

-- DELETE: only the assigner or the president.
drop policy if exists "tasks_delete" on public.tasks;
create policy "tasks_delete" on public.tasks
  for delete to authenticated using (
    assigned_by = auth.uid()
    or public.is_my_club_president(tasks.club_id)
  );

-- Activity log: record each assignment so the president can follow
-- every task (assignment + started/completed status trail) from the
-- log. Same conventions as 20260626000000_activity_log_triggers.sql:
-- SECURITY DEFINER + swallow logging errors.
create or replace function public.log_task_assigned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_assignee text;
begin
  select full_name into v_assignee
  from public.profiles where id = new.assigned_to;

  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id,
      coalesce(new.assigned_by, auth.uid()),
      'task_assigned',
      jsonb_build_object(
        'title', new.title,
        'task_id', new.id,
        'assignee_name', v_assignee
      )
    );
  exception when others then
    null; -- never block the task insert
  end;

  return new;
end;
$$;

drop trigger if exists trg_log_task_assigned on public.tasks;
create trigger trg_log_task_assigned
  after insert on public.tasks
  for each row execute function public.log_task_assigned();
