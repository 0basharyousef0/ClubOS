-- RPC to notify the club president of a new join request.
-- SECURITY DEFINER bypasses RLS so a pending user can find the president
-- and insert their notification even before they're approved.
CREATE OR REPLACE FUNCTION public.notify_club_president_of_join(
  p_club_id uuid,
  p_role_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_president_id uuid;
  v_requester_name text;
BEGIN
  SELECT user_id INTO v_president_id
  FROM public.user_club_roles
  WHERE club_id = p_club_id
    AND role = 'president'
    AND status = 'approved'
  LIMIT 1;

  IF v_president_id IS NULL THEN
    RETURN;
  END IF;

  SELECT full_name INTO v_requester_name
  FROM public.profiles
  WHERE id = auth.uid();

  INSERT INTO public.notifications (user_id, club_id, type, message)
  VALUES (
    v_president_id,
    p_club_id,
    'join_request',
    coalesce(v_requester_name, 'Someone') || ' wants to join as ' || p_role_name
  );
END;
$$;
