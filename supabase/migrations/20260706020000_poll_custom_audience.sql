-- ============================================================
-- ClubOS — Poll audiences as explicit voter lists
--
-- Each poll now snapshots exactly who can see/vote it into
-- poll_eligible_voters at creation time (audiences: all club members,
-- VPs & president, a VP's own directors, or a custom hand-picked
-- list). Visibility and voting are enforced from that list — even the
-- president only votes where selected; their oversight is the
-- activity log, which now also records poll creation. When the last
-- eligible voter votes, the poll closes itself.
--
-- Also adds user_club_roles.reports_to: directors record which VP
-- they work under (captured at join; seeded roster backfilled by
-- matching titles) — powers the "My Directors" audience.
-- ============================================================

-- 1. VP <-> director link
alter table public.user_club_roles
  add column if not exists reports_to uuid references public.profiles(id);

-- Backfill seeded directors from the title convention
-- ('VP Events' -> 'Events Director').
update public.user_club_roles dir
set reports_to = vp.user_id
from public.user_club_roles vp
where dir.role = 'director'
  and dir.reports_to is null
  and vp.club_id = dir.club_id
  and vp.role = 'vice_president'
  and vp.status = 'approved'
  and vp.role_title is not null
  and dir.role_title = regexp_replace(vp.role_title, '^VP\s+(of\s+)?', '', 'i') || ' Director';

-- 2. Allow the new audience values
alter table public.polls drop constraint if exists polls_audience_check;
alter table public.polls add constraint polls_audience_check
  check (audience in ('all', 'vps_only', 'directors_only',
                      'my_directors', 'custom'));

-- 3. Eligible-voter snapshot per poll
create table if not exists public.poll_eligible_voters (
  poll_id uuid not null references public.polls(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (poll_id, user_id)
);

alter table public.poll_eligible_voters enable row level security;

-- The default privileges here don't cover DML for API roles; RLS
-- policies below do the actual gating.
grant select, insert, delete on public.poll_eligible_voters to authenticated;

-- SECURITY DEFINER helpers: polls policies reference this table and
-- vice versa, so plain policies would recurse. Same pattern as
-- is_my_club_president (20260602000001).
create or replace function public.is_poll_creator(p_poll_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from polls where id = p_poll_id and created_by = auth.uid()
  );
$$;

create or replace function public.am_i_eligible_voter(p_poll_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from poll_eligible_voters
    where poll_id = p_poll_id and user_id = auth.uid()
  );
$$;

revoke execute on function public.is_poll_creator(uuid) from public, anon;
revoke execute on function public.am_i_eligible_voter(uuid) from public, anon;
grant execute on function public.is_poll_creator(uuid) to authenticated;
grant execute on function public.am_i_eligible_voter(uuid) to authenticated;

create policy "pev_select" on public.poll_eligible_voters
  for select to authenticated using (
    user_id = auth.uid() or public.is_poll_creator(poll_id)
  );

create policy "pev_insert" on public.poll_eligible_voters
  for insert to authenticated with check (
    public.is_poll_creator(poll_id)
  );

create policy "pev_delete" on public.poll_eligible_voters
  for delete to authenticated using (
    public.is_poll_creator(poll_id)
  );

-- 3. Backfill voter lists for existing polls from their legacy
-- audience semantics.
insert into public.poll_eligible_voters (poll_id, user_id)
select p.id, ucr.user_id
from public.polls p
join public.user_club_roles ucr
  on ucr.club_id = p.club_id and ucr.status = 'approved'
where p.audience = 'all'
   or (p.audience = 'vps_only' and ucr.role in ('president', 'vice_president'))
   or (p.audience = 'directors_only' and ucr.role = 'director')
on conflict do nothing;

-- 4. Re-point poll visibility/voting at the voter list
drop policy if exists "polls_select" on public.polls;
create policy "polls_select" on public.polls
  for select to authenticated using (
    created_by = auth.uid() or public.am_i_eligible_voter(id)
  );

drop policy if exists "poll_options_select" on public.poll_options;
create policy "poll_options_select" on public.poll_options
  for select to authenticated using (
    public.is_poll_creator(poll_id) or public.am_i_eligible_voter(poll_id)
  );

drop policy if exists "poll_options_insert" on public.poll_options;
create policy "poll_options_insert" on public.poll_options
  for insert to authenticated with check (
    public.is_poll_creator(poll_id)
  );

drop policy if exists "poll_votes_select" on public.poll_votes;
create policy "poll_votes_select" on public.poll_votes
  for select to authenticated using (
    public.is_poll_creator(poll_id) or public.am_i_eligible_voter(poll_id)
  );

drop policy if exists "poll_votes_insert" on public.poll_votes;
create policy "poll_votes_insert" on public.poll_votes
  for insert to authenticated with check (
    user_id = auth.uid() and public.am_i_eligible_voter(poll_id)
  );

-- 5. Auto-close once every eligible voter has voted
create or replace function public.close_poll_when_all_voted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eligible int;
  v_voted int;
begin
  select count(*) into v_eligible
  from poll_eligible_voters where poll_id = new.poll_id;

  if v_eligible = 0 then
    return new;
  end if;

  select count(distinct pv.user_id) into v_voted
  from poll_votes pv
  join poll_eligible_voters pev
    on pev.poll_id = pv.poll_id and pev.user_id = pv.user_id
  where pv.poll_id = new.poll_id;

  if v_voted >= v_eligible then
    update polls set closes_at = now()
    where id = new.poll_id
      and (closes_at is null or closes_at > now());
  end if;

  return new;
end;
$$;

drop trigger if exists trg_close_poll_when_all_voted on public.poll_votes;
create trigger trg_close_poll_when_all_voted
  after insert on public.poll_votes
  for each row execute function public.close_poll_when_all_voted();

-- 6. Log poll creation so the president sees every poll in the
-- activity log (same conventions as the other log triggers).
create or replace function public.log_poll_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id, new.created_by, 'poll_created',
      jsonb_build_object('title', new.title, 'poll_id', new.id)
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists trg_log_poll_created on public.polls;
create trigger trg_log_poll_created
  after insert on public.polls
  for each row execute function public.log_poll_created();
