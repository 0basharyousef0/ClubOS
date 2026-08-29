-- ============================================================
-- ClubOS — Leave a single club
--
-- Until now the only way out of a club was to be removed by the
-- president or to delete your whole account — which also destroyed
-- your membership in every OTHER club. leave_club() lets a VP or
-- director step out of one club and keep everything else.
--
-- Presidents cannot leave: a club can't be left headless, so they
-- transfer presidency or delete the club first (same rule
-- delete_account() enforces).
--
-- The membership row is KEPT with status 'left' rather than
-- deleted. profiles_select (20260730000000) grants profile reads to
-- people who share a club via user_club_roles; hard-deleting the row
-- would strip that grant and every task, comment and poll the
-- leaver authored would render with a blank name. Directory,
-- pickers and the approvals queue all filter on
-- 'approved'/'pending', so a 'left' row is invisible to them, and
-- the app's routing only ever looks at isApproved/isPending.
-- ============================================================

-- ── 1. Allow the new status ───────────────────────────────────

alter table public.user_club_roles
  drop constraint if exists user_club_roles_status_check;
alter table public.user_club_roles
  add constraint user_club_roles_status_check
  check (status in ('pending', 'approved', 'rejected', 'left'));

-- ── 2. Let a leaver re-request membership ─────────────────────
-- UNIQUE (user_id, club_id) means rejoining has to update the old
-- row, but ucr_update is president-only. This narrow policy lets a
-- user flip their OWN 'left' row back to 'pending' (and nothing
-- else), so the client's upsert in joinClub() works and leaving is
-- never a permanent ban.

drop policy if exists "ucr_rejoin" on public.user_club_roles;
create policy "ucr_rejoin" on public.user_club_roles
  for update to authenticated
  using (user_id = auth.uid() and status = 'left')
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and role in ('vice_president', 'director')
  );

-- ── 3. leave_club() ───────────────────────────────────────────
-- Mirrors the departure bookkeeping in delete_account() 4b–4e,
-- scoped to one club and without touching the account itself.

create or replace function public.leave_club(p_club_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text;
  v_display text;
  v_title text;
  v_orphan_ids uuid[] := '{}';
  v_open_poll_ids uuid[] := '{}';
  v_row public.user_club_roles%rowtype;
  v_club_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_row
  from user_club_roles
  where club_id = p_club_id and user_id = v_uid and status = 'approved';

  if not found then
    raise exception 'You are not an approved member of this club.';
  end if;

  select name into v_club_name from clubs where id = p_club_id;

  if v_row.role = 'president' then
    raise exception
      'You are the president of "%". Transfer presidency or delete the club before leaving.',
      coalesce(v_club_name, 'this club');
  end if;

  select full_name into v_name from profiles where id = v_uid;
  v_display := coalesce(nullif(trim(v_name), ''), 'A member');

  -- President-only audit trail.
  insert into activity_log (club_id, user_id, action_type, details)
  values (
    p_club_id, v_uid, 'member_left',
    jsonb_build_object('role', v_row.role, 'role_title', v_row.role_title,
                       'left_club', true)
  );

  if v_row.role = 'vice_president' then
    v_title := coalesce(nullif(trim(v_row.role_title), ''), 'Vice President');

    select coalesce(array_agg(user_id), '{}') into v_orphan_ids
    from user_club_roles
    where club_id = p_club_id and reports_to = v_uid
      and role = 'director' and status = 'approved';

    insert into notifications (user_id, club_id, type, message)
    select p.user_id, p_club_id, 'member_left',
      case
        when coalesce(array_length(v_orphan_ids, 1), 0) > 0 then
          v_display || ' (' || v_title || ') left the club. '
            || array_length(v_orphan_ids, 1)
            || ' director(s) are now without a VP — the club is missing a '
            || v_title || '.'
        else
          v_display || ' (' || v_title || ') left the club.'
      end
    from user_club_roles p
    where p.club_id = p_club_id
      and p.role = 'president' and p.status = 'approved';

    if coalesce(array_length(v_orphan_ids, 1), 0) > 0 then
      insert into notifications (user_id, club_id, type, message)
      select unnest(v_orphan_ids), p_club_id, 'member_left',
             'Your VP ' || v_display || ' (' || v_title
               || ') left the club. The president has been notified that the club is missing a '
               || v_title || '.';
    end if;

  elsif v_row.role = 'director' then
    v_title := coalesce(nullif(trim(v_row.role_title), ''), 'Director');

    insert into notifications (user_id, club_id, type, message)
    select distinct x.user_id, p_club_id, 'member_left',
           v_display || ' (' || v_title || ') left the club.'
    from (
      select p.user_id from user_club_roles p
      where p.club_id = p_club_id
        and p.role = 'president' and p.status = 'approved'
      union
      select vp.user_id from user_club_roles vp
      where vp.club_id = p_club_id
        and vp.user_id = v_row.reports_to and vp.status = 'approved'
    ) x;
  end if;

  -- Directors who reported to this VP — scoped to THIS club, unlike
  -- delete_account() which clears the link everywhere.
  update user_club_roles
  set reports_to = null
  where club_id = p_club_id and reports_to = v_uid;

  -- The membership itself: kept as a tombstone (see header).
  update user_club_roles
  set status = 'left', reports_to = null, role_title = null
  where id = v_row.id;

  -- Future commitments go; past history stays.
  delete from event_rsvps er
  using events e
  where er.event_id = e.id
    and er.user_id = v_uid
    and e.club_id = p_club_id
    and e.event_date > now();

  delete from meeting_attendees ma
  using meetings m
  where ma.meeting_id = m.id
    and ma.user_id = v_uid
    and m.club_id = p_club_id
    and m.scheduled_at > now();

  -- Open polls in this club they haven't voted in: drop them from
  -- the eligible list so live polls don't wait on a departed member.
  select coalesce(array_agg(pev.poll_id), '{}') into v_open_poll_ids
  from poll_eligible_voters pev
  join polls p on p.id = pev.poll_id
  where pev.user_id = v_uid
    and p.club_id = p_club_id
    and (p.closes_at is null or p.closes_at > now())
    and not exists (
      select 1 from poll_votes pv
      where pv.poll_id = pev.poll_id and pv.user_id = v_uid
    );

  delete from poll_eligible_voters
  where user_id = v_uid and poll_id = any(v_open_poll_ids);

  -- Mirror the auto-close rule: with the leaver out of the list, a
  -- poll where everyone remaining has voted closes now.
  update polls p
  set closes_at = now()
  where p.id = any(v_open_poll_ids)
    and (p.closes_at is null or p.closes_at > now())
    and (select count(*) from poll_eligible_voters pev
         where pev.poll_id = p.id) > 0
    and (select count(*) from poll_eligible_voters pev
         where pev.poll_id = p.id)
        <= (select count(distinct pv.user_id)
            from poll_votes pv
            join poll_eligible_voters pev2
              on pev2.poll_id = pv.poll_id and pev2.user_id = pv.user_id
            where pv.poll_id = p.id);

  -- Their inbox for this club only; other clubs' notifications and
  -- their device tokens are untouched.
  delete from notifications
  where user_id = v_uid and club_id = p_club_id;
end;
$$;

revoke execute on function public.leave_club(uuid) from public, anon;
grant execute on function public.leave_club(uuid) to authenticated;
