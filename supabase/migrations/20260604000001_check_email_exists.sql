-- RPC callable by the anon key to check if an email is registered.
-- SECURITY DEFINER allows reading auth.users without elevated privileges.
CREATE OR REPLACE FUNCTION public.check_email_exists(p_email text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (SELECT 1 FROM auth.users WHERE email = lower(p_email));
$$;
