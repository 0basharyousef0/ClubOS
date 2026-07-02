-- ============================================================
-- ClubOS — Function privilege hardening
-- Addresses the Supabase security advisor warnings:
--   * function_search_path_mutable (check_email_exists)
--   * anon/authenticated_security_definer_function_executable
--
-- Postgres grants EXECUTE on new functions to PUBLIC by default,
-- which exposes every RPC to the anon role via PostgREST. This
-- migration pins search_path on the definer functions that were
-- missing it and scopes EXECUTE to the roles that actually need
-- each function.
-- ============================================================

-- ── Pin search_path on definer functions that were missing it ──
alter function public.check_email_exists(text) set search_path = public;
alter function public.notify_club_president_of_join(uuid, text)
  set search_path = public;

-- ── RPCs used by the signed-in app: authenticated only ─────────
revoke execute on function public.create_club_with_president(text)
  from public, anon;
revoke execute on function public.list_clubs_for_dropdown()
  from public, anon;
revoke execute on function public.check_club_name_available(text)
  from public, anon;
revoke execute on function public.get_my_approved_club_ids()
  from public, anon;
revoke execute on function public.is_my_club_president(uuid)
  from public, anon;
revoke execute on function public.notify_club_president_of_join(uuid, text)
  from public, anon;

grant execute on function public.create_club_with_president(text) to authenticated;
grant execute on function public.list_clubs_for_dropdown() to authenticated;
grant execute on function public.check_club_name_available(text) to authenticated;
grant execute on function public.get_my_approved_club_ids() to authenticated;
grant execute on function public.is_my_club_president(uuid) to authenticated;
grant execute on function public.notify_club_president_of_join(uuid, text) to authenticated;

-- check_email_exists stays callable by anon: the login screen uses it
-- pre-auth. Email enumeration via this RPC is a documented, accepted
-- risk (SECURITY_AUDIT.md MED-05).
revoke execute on function public.check_email_exists(text) from public;
grant execute on function public.check_email_exists(text) to anon, authenticated;

-- ── Trigger functions: never callable via RPC ──────────────────
-- Triggers execute as the table owner, so revoking EXECUTE from API
-- roles does not affect them.
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
revoke execute on function public.sync_auth_email_to_profile()
  from public, anon, authenticated;
revoke execute on function public.notify_on_task_assigned()
  from public, anon, authenticated;
revoke execute on function public.notify_on_event_posted()
  from public, anon, authenticated;
revoke execute on function public.notify_on_announcement_posted()
  from public, anon, authenticated;
revoke execute on function public.notify_on_membership_approved()
  from public, anon, authenticated;
revoke execute on function public.log_task_status_change()
  from public, anon, authenticated;
revoke execute on function public.log_announcement_posted()
  from public, anon, authenticated;
revoke execute on function public.log_event_rsvp()
  from public, anon, authenticated;
revoke execute on function public.log_poll_vote()
  from public, anon, authenticated;

-- rls_auto_enable exists only on the hosted project (added via the
-- dashboard), so guard it for fresh local databases.
do $$
begin
  revoke execute on function public.rls_auto_enable()
    from public, anon, authenticated;
exception
  when undefined_function then null;
end;
$$;
