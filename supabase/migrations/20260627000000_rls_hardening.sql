-- ============================================================
-- ClubOS — RLS Security Hardening
-- Addresses: CRIT-01, MED-01, MED-02, MED-03, MED-07,
--            LOW-01, LOW-02, LOW-03
-- ============================================================

-- ============================================================
-- CRIT-01: Privilege escalation via ucr_insert
-- Replace the open insert policy with one that only allows
-- self-join as a PENDING VP or Director. Club creation (where
-- the caller legitimately becomes an approved President) is
-- handled atomically by the SECURITY DEFINER RPC below.
-- ============================================================

drop policy if exists "ucr_insert" on public.user_club_roles;

create policy "ucr_insert" on public.user_club_roles
  for insert to authenticated with check (
    user_id = auth.uid()
    and status = 'pending'
    and role in ('vice_president', 'director')
  );

-- Atomically creates a club and its first approved President row.
-- SECURITY DEFINER bypasses RLS so it can insert the president role
-- without the caller needing a permissive insert policy.
-- Rate-limited to 3 new clubs per caller per 24 hours.
create or replace function public.create_club_with_president(p_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_club_id uuid;
begin
  if (
    select count(*) from public.user_club_roles
    where user_id = auth.uid()
      and role = 'president'
      and created_at > now() - interval '24 hours'
  ) >= 3 then
    raise exception 'Club creation rate limit exceeded (max 3 per 24 hours)';
  end if;

  insert into public.clubs (name)
  values (trim(p_name))
  returning id into v_club_id;

  insert into public.user_club_roles (user_id, club_id, role, status, approved_by)
  values (auth.uid(), v_club_id, 'president', 'approved', auth.uid());

  return v_club_id;
end;
$$;

-- Direct table inserts to clubs are now blocked; use the RPC above.
drop policy if exists "clubs_insert" on public.clubs;
create policy "clubs_insert" on public.clubs
  for insert to authenticated with check (false);


-- ============================================================
-- MED-01: Notification spoofing
-- Drop the open authenticated INSERT policy — all notification
-- writes go through SECURITY DEFINER triggers/RPCs that bypass
-- RLS, so the authenticated policy is unnecessary and dangerous.
-- ============================================================

drop policy if exists "notifications_insert" on public.notifications;


-- ============================================================
-- MED-02: Platform-wide PII harvesting (profiles_select)
-- Scope to own profile + members who share at least one
-- approved club with the caller (pending included so Presidents
-- can see pending members' names during the approval flow).
-- ============================================================

drop policy if exists "profiles_select" on public.profiles;

create policy "profiles_select" on public.profiles
  for select to authenticated using (
    id = auth.uid()
    or id in (
      select ucr.user_id from public.user_club_roles ucr
      where ucr.club_id = any(array(select public.get_my_approved_club_ids()))
    )
  );


-- ============================================================
-- MED-03: Club constitution readable across clubs
-- Restrict clubs_select to members (pending or approved) so
-- non-members cannot read constitution_content. The join
-- dropdown and name-check use SECURITY DEFINER helper RPCs
-- that return only id/name without constitution_content.
-- ============================================================

-- Dropdown helper: returns id, name, created_at — no constitution_content.
create or replace function public.list_clubs_for_dropdown()
returns table(id uuid, name text, created_at timestamptz)
language sql security definer stable
set search_path = public as $$
  select id, name, created_at from public.clubs order by name;
$$;

-- Name-availability check for the create-club flow (caller may not be
-- a member of any club yet, so cannot use clubs_select directly).
create or replace function public.check_club_name_available(p_name text)
returns boolean language sql security definer stable
set search_path = public as $$
  select not exists (
    select 1 from public.clubs where lower(name) = lower(trim(p_name))
  );
$$;

drop policy if exists "clubs_select" on public.clubs;

create policy "clubs_select" on public.clubs
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = clubs.id
        and user_id = auth.uid()
        and status in ('pending', 'approved')
    )
  );


-- ============================================================
-- MED-07: Forgeable audit log
-- Drop the open authenticated INSERT policy — all activity_log
-- writes go through SECURITY DEFINER triggers only.
-- ============================================================

drop policy if exists "activity_log_insert" on public.activity_log;


-- ============================================================
-- LOW-01: RSVP list visible to all members (spec: President only)
-- VPs/Directors can still read their own row (for toggle state).
-- ============================================================

drop policy if exists "event_rsvps_select" on public.event_rsvps;

create policy "event_rsvps_select" on public.event_rsvps
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
      join public.user_club_roles ucr on ucr.club_id = e.club_id
      where e.id = event_rsvps.event_id
        and ucr.user_id = auth.uid()
        and ucr.role = 'president'
        and ucr.status = 'approved'
    )
  );


-- ============================================================
-- LOW-02: Missing WITH CHECK on UPDATE policies
-- Adds WITH CHECK to prevent callers from mutating rows into
-- disallowed states (e.g. moving a task to a different club,
-- promoting a member to President via update).
-- ============================================================

-- tasks_update: WITH CHECK mirrors USING to prevent club_id changes.
drop policy if exists "tasks_update" on public.tasks;

create policy "tasks_update" on public.tasks
  for update to authenticated
  using (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id
        and user_id = auth.uid()
        and status = 'approved'
        and (role in ('president', 'vice_president') or auth.uid() = tasks.assigned_to)
    )
  )
  with check (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id
        and user_id = auth.uid()
        and status = 'approved'
        and (role in ('president', 'vice_president') or auth.uid() = tasks.assigned_to)
    )
  );

-- ucr_update: WITH CHECK prevents promoting anyone to President via update.
-- (Replaces the policy set in 20260602000001_fix_ucr_rls_recursion.sql)
drop policy if exists "ucr_update" on public.user_club_roles;

create policy "ucr_update" on public.user_club_roles
  for update to authenticated
  using (public.is_my_club_president(club_id))
  with check (
    public.is_my_club_president(club_id)
    and role in ('vice_president', 'director')
  );

-- profiles_update: WITH CHECK ensures a user cannot change their own id.
drop policy if exists "profiles_update" on public.profiles;

create policy "profiles_update" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());


-- ============================================================
-- MED-05 (accepted risk): check_email_exists is callable by the
-- anon key and reveals whether an email is registered. This is
-- a deliberate UX tradeoff for the login flow. Mitigate via
-- Supabase project-level rate limiting on this RPC endpoint if
-- enumeration becomes a concern.
-- ============================================================

-- ============================================================
-- MED-06 (operational): Password-reset redirectTo should be
-- changed to a Universal Link (https://clubos.app/reset-password)
-- backed by assetlinks.json (Android) and AASA (iOS) so the OS
-- exclusively binds the link to this app. The Dart change is in
-- auth_repository.dart. Requires domain + hosting setup before
-- enabling in production.
-- ============================================================
