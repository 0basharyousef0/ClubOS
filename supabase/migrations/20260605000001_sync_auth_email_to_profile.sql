-- Trigger: keep profiles.email in sync with auth.users.email
-- Fires after Supabase confirms an email-change request (when user clicks
-- the confirmation link). The app cannot update profiles.email earlier
-- because auth.users.email only changes at confirmation time.

CREATE OR REPLACE FUNCTION sync_auth_email_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET email = NEW.email
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_email_updated ON auth.users;
CREATE TRIGGER on_auth_user_email_updated
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (OLD.email IS DISTINCT FROM NEW.email)
  EXECUTE FUNCTION sync_auth_email_to_profile();
