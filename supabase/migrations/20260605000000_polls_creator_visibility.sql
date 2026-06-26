-- Poll creators must always be able to see their own polls,
-- even when the audience targets a role they don't belong to
-- (e.g. VP creating a directors_only poll).
DROP POLICY IF EXISTS "polls_select" ON public.polls;

CREATE POLICY "polls_select" ON public.polls
  FOR SELECT TO authenticated USING (
    created_by = auth.uid()
    OR exists (
      SELECT 1 FROM public.user_club_roles ucr
      WHERE ucr.club_id = polls.club_id
        AND ucr.user_id = auth.uid()
        AND ucr.status = 'approved'
        AND (
          polls.audience = 'all'
          OR (polls.audience = 'vps_only'      AND ucr.role IN ('president', 'vice_president'))
          OR (polls.audience = 'directors_only' AND ucr.role = 'director')
        )
    )
  );
