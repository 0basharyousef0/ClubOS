-- ============================================================
-- ClubOS — List a club's approved VPs for the director signup flow
-- Directors pick which VP they work under when requesting to join
-- a club, and the app derives their title from the VP's
-- (VP Finance -> Finance Director). A joining user is not a member
-- yet, so RLS blocks reading user_club_roles directly — this
-- SECURITY DEFINER function exposes only the minimum needed:
-- approved vice presidents' names and titles for one club.
-- Also formalises the role_title column locally (it already exists
-- on the live database).
-- ============================================================

alter table public.user_club_roles
  add column if not exists role_title text;

create or replace function public.list_club_vps(p_club_id uuid)
returns table (user_id uuid, full_name text, role_title text)
language sql
security definer
set search_path = public
stable
as $$
  select ucr.user_id, p.full_name, ucr.role_title
  from public.user_club_roles ucr
  join public.profiles p on p.id = ucr.user_id
  where ucr.club_id = p_club_id
    and ucr.role = 'vice_president'
    and ucr.status = 'approved'
  order by p.full_name;
$$;

revoke execute on function public.list_club_vps(uuid) from public, anon;
grant execute on function public.list_club_vps(uuid) to authenticated;
