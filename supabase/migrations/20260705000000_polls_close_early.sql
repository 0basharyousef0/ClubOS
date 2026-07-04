-- ============================================================
-- ClubOS — Let a poll's creator close it early
-- The app closes a poll by setting closes_at = now(). Polls had no
-- UPDATE policy at all, so add one scoped to the creator only —
-- deliberately narrower than delete (which also allows the
-- president): closing early is the creator's call.
-- ============================================================

create policy "polls_update" on public.polls
  for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());
