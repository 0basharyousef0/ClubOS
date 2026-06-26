-- Fix infinite recursion in user_club_roles RLS policies.
-- The original policies queried user_club_roles from within user_club_roles policies,
-- causing a recursive loop. Security definer functions bypass RLS entirely,
-- breaking the cycle.

create or replace function public.get_my_approved_club_ids()
returns setof uuid language sql security definer stable
set search_path = public as $$
  select club_id from user_club_roles
  where user_id = auth.uid() and status = 'approved';
$$;

create or replace function public.is_my_club_president(p_club_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from user_club_roles
    where club_id = p_club_id
      and user_id = auth.uid()
      and role = 'president'
      and status = 'approved'
  );
$$;

-- Replace the three recursive policies
drop policy if exists "ucr_select" on public.user_club_roles;
drop policy if exists "ucr_update" on public.user_club_roles;
drop policy if exists "ucr_delete" on public.user_club_roles;

-- Users can see their own rows, or any row for a club they're approved in
create policy "ucr_select" on public.user_club_roles
  for select to authenticated using (
    user_id = auth.uid()
    or club_id = any(array(select public.get_my_approved_club_ids()))
  );

-- Only the club's President can update (approve/reject) roles
create policy "ucr_update" on public.user_club_roles
  for update to authenticated using (
    public.is_my_club_president(club_id)
  );

-- Users can delete their own role (leave club), or President can remove anyone
create policy "ucr_delete" on public.user_club_roles
  for delete to authenticated using (
    user_id = auth.uid()
    or public.is_my_club_president(club_id)
  );
