-- ============================================================
-- ClubOS — Self-serve account deletion & presidency transfer
-- (App Store Guideline 5.1.1(v): apps with account creation must
-- let users delete their account in-app.)
--
-- Design: deleting an account erases the person, keeps the work.
--   * The auth.users row is deleted — login, password hash, auth
--     email, metadata, sessions and identities are all gone.
--   * The profiles row becomes an anonymized tombstone
--     ("Former member", emails cleared, deleted_at set) so
--     historical tasks, comments, attachments, events,
--     announcements, polls and votes keep valid references and
--     render a neutral name.
--   * All memberships (user_club_roles) are deleted, which
--     removes the user from the directory, member pickers and
--     VP dropdowns.
--   * Hierarchy stays intact: a president must first transfer
--     presidency (transfer_presidency below) or delete the club;
--     if the president is the club's only approved member the
--     club dissolves with the account. When a VP leaves, their
--     directors are unlinked and the team is told the club is
--     missing that VP position (e.g. "missing a VP Events").
-- ============================================================

-- ── 1. Tombstone support on profiles ──────────────────────────

alter table public.profiles
  add column if not exists deleted_at timestamptz;

-- The tombstone must outlive the auth user, so the FK to
-- auth.users (ON DELETE CASCADE) has to go. Profile rows are
-- still only ever created by the handle_new_user() trigger, so
-- ids remain 1:1 with real signups.
alter table public.profiles drop constraint if exists profiles_id_fkey;

-- Tombstones hold no PII and must stay readable by everyone who
-- can see the work they're attached to (task comments, polls,
-- activity log …), even though the leaver no longer shares a
-- club with anyone. Extends the MED-02 policy.
drop policy if exists "profiles_select" on public.profiles;

create policy "profiles_select" on public.profiles
  for select to authenticated using (
    id = auth.uid()
    or deleted_at is not null
    or id in (
      select ucr.user_id from public.user_club_roles ucr
      where ucr.club_id = any(array(select public.get_my_approved_club_ids()))
    )
  );

-- ── 2. Orphan-director re-adoption ────────────────────────────
-- When a VP leaves (or ascends to president), their directors'
-- reports_to is cleared. When a replacement VP is approved, adopt
-- the title-matched orphans automatically — same convention as
-- the 20260706020000 backfill ('VP Events' -> 'Events Director').

create or replace function public.relink_directors_on_vp_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role = 'vice_president'
     and new.status = 'approved'
     and old.status is distinct from 'approved'
     and nullif(trim(new.role_title), '') is not null then
    update public.user_club_roles dir
    set reports_to = new.user_id
    where dir.club_id = new.club_id
      and dir.role = 'director'
      and dir.reports_to is null
      and dir.role_title =
        regexp_replace(new.role_title, '^VP\s+(of\s+)?', '', 'i') || ' Director';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_relink_directors_on_vp_approval
  on public.user_club_roles;
create trigger trg_relink_directors_on_vp_approval
  after update on public.user_club_roles
  for each row execute function public.relink_directors_on_vp_approval();

-- ── 3. Presidency transfer ────────────────────────────────────
-- The president hands the club to another approved member and
-- becomes a Vice President. If the successor was a VP, their
-- directors are unlinked and told the club is missing that VP
-- position (until a replacement is approved and re-adopts them).

create or replace function public.transfer_presidency(
  p_club_id uuid,
  p_new_president_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_club_name text;
  v_new_name text;
  v_new_row public.user_club_roles%rowtype;
  v_vp_title text;
  v_orphan_ids uuid[] := '{}';
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  if not exists (
    select 1 from user_club_roles
    where club_id = p_club_id and user_id = v_uid
      and role = 'president' and status = 'approved'
  ) then
    raise exception 'Only the club president can transfer presidency.';
  end if;

  if p_new_president_id = v_uid then
    raise exception 'You are already the president of this club.';
  end if;

  select * into v_new_row
  from user_club_roles
  where club_id = p_club_id and user_id = p_new_president_id
    and status = 'approved';

  if not found then
    raise exception 'The new president must be an approved member of this club.';
  end if;

  select name into v_club_name from clubs where id = p_club_id;
  select full_name into v_new_name from profiles where id = p_new_president_id;
  v_new_name := coalesce(nullif(trim(v_new_name), ''), 'A member');

  -- A VP moving up leaves their directors without a VP.
  if v_new_row.role = 'vice_president' then
    v_vp_title := coalesce(nullif(trim(v_new_row.role_title), ''), 'Vice President');

    select coalesce(array_agg(user_id), '{}') into v_orphan_ids
    from user_club_roles
    where club_id = p_club_id and reports_to = p_new_president_id
      and role = 'director' and status = 'approved';

    update user_club_roles
    set reports_to = null
    where club_id = p_club_id and reports_to = p_new_president_id;
  end if;

  -- Swap roles: outgoing president becomes a VP, successor becomes
  -- president. Titles reset; RLS reads roles live, so all
  -- president-only powers move instantly with the row update.
  update user_club_roles
  set role = 'vice_president', role_title = null
  where club_id = p_club_id and user_id = v_uid;

  update user_club_roles
  set role = 'president', role_title = null, reports_to = null
  where club_id = p_club_id and user_id = p_new_president_id;

  -- Tell the club.
  insert into notifications (user_id, club_id, type, message)
  values (
    p_new_president_id, p_club_id, 'presidency_transferred',
    'You are now the president of ' || coalesce(v_club_name, 'your club') || '.'
  );

  insert into notifications (user_id, club_id, type, message)
  select ucr.user_id, p_club_id, 'presidency_transferred',
         v_new_name || ' is now the president of '
           || coalesce(v_club_name, 'the club') || '.'
  from user_club_roles ucr
  where ucr.club_id = p_club_id
    and ucr.status = 'approved'
    and ucr.user_id not in (v_uid, p_new_president_id);

  -- Directors orphaned by their VP's promotion get the specifics.
  if coalesce(array_length(v_orphan_ids, 1), 0) > 0 then
    insert into notifications (user_id, club_id, type, message)
    select unnest(v_orphan_ids), p_club_id, 'member_left',
           'Your VP ' || v_new_name || ' became president — the club is missing a '
             || v_vp_title || '.';
  end if;

  insert into activity_log (club_id, user_id, action_type, details)
  values (
    p_club_id, v_uid, 'presidency_transferred',
    jsonb_build_object(
      'new_president', v_new_name,
      'new_president_id', p_new_president_id
    )
  );
end;
$$;

-- ── 4. Account deletion ───────────────────────────────────────

create or replace function public.delete_account()
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
  v_orphan_ids uuid[];
  v_open_poll_ids uuid[];
  r record;
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select full_name into v_name from profiles where id = v_uid;
  if not found then
    raise exception 'No account found.';
  end if;
  v_display := coalesce(nullif(trim(v_name), ''), 'A member');

  -- 4a. Presidents must hand over or dissolve their clubs first.
  -- A club whose president is its only approved member dissolves
  -- with the account (cascades roles, tasks, events, polls …).
  for r in
    select ucr.club_id, c.name
    from user_club_roles ucr
    join clubs c on c.id = ucr.club_id
    where ucr.user_id = v_uid
      and ucr.role = 'president'
      and ucr.status = 'approved'
  loop
    if exists (
      select 1 from user_club_roles o
      where o.club_id = r.club_id
        and o.status = 'approved'
        and o.user_id <> v_uid
    ) then
      raise exception
        'You are the president of "%". Transfer presidency or delete the club before deleting your account.',
        r.name;
    else
      delete from clubs where id = r.club_id;
    end if;
  end loop;

  -- 4b. Departure bookkeeping per remaining club (VPs/directors —
  -- president rows were all handled above).
  for r in
    select ucr.*, c.name as club_name
    from user_club_roles ucr
    join clubs c on c.id = ucr.club_id
    where ucr.user_id = v_uid and ucr.status = 'approved'
  loop
    -- President-only audit trail. Deliberately name-free: the
    -- tombstone profile renders as "Former member".
    insert into activity_log (club_id, user_id, action_type, details)
    values (
      r.club_id, v_uid, 'member_left',
      jsonb_build_object('role', r.role, 'role_title', r.role_title)
    );

    if r.role = 'vice_president' then
      v_title := coalesce(nullif(trim(r.role_title), ''), 'Vice President');

      select coalesce(array_agg(user_id), '{}') into v_orphan_ids
      from user_club_roles
      where club_id = r.club_id and reports_to = v_uid
        and role = 'director' and status = 'approved';

      -- The president hears what position is now missing.
      insert into notifications (user_id, club_id, type, message)
      select p.user_id, r.club_id, 'member_left',
        case
          when coalesce(array_length(v_orphan_ids, 1), 0) > 0 then
            v_display || ' (' || v_title || ') deleted their account. '
              || array_length(v_orphan_ids, 1)
              || ' director(s) are now without a VP — the club is missing a '
              || v_title || '.'
          else
            v_display || ' (' || v_title
              || ') deleted their account and left the club.'
        end
      from user_club_roles p
      where p.club_id = r.club_id
        and p.role = 'president' and p.status = 'approved';

      -- Their directors hear it too.
      if coalesce(array_length(v_orphan_ids, 1), 0) > 0 then
        insert into notifications (user_id, club_id, type, message)
        select unnest(v_orphan_ids), r.club_id, 'member_left',
               'Your VP ' || v_display || ' (' || v_title
                 || ') left the club. The president has been notified that the club is missing a '
                 || v_title || '.';
      end if;

    elsif r.role = 'director' then
      v_title := coalesce(nullif(trim(r.role_title), ''), 'Director');

      -- President and (if any) the VP they reported to.
      insert into notifications (user_id, club_id, type, message)
      select distinct x.user_id, r.club_id, 'member_left',
             v_display || ' (' || v_title
               || ') deleted their account and left the club.'
      from (
        select p.user_id from user_club_roles p
        where p.club_id = r.club_id
          and p.role = 'president' and p.status = 'approved'
        union
        select vp.user_id from user_club_roles vp
        where vp.club_id = r.club_id
          and vp.user_id = r.reports_to and vp.status = 'approved'
      ) x;
    end if;
  end loop;

  -- 4c. Unlink hierarchy references to the leaver (directors —
  -- approved or pending — who reported to this VP).
  update user_club_roles set reports_to = null where reports_to = v_uid;

  -- 4d. Memberships: gone from the directory, pickers, approvals.
  delete from user_club_roles where user_id = v_uid;

  -- 4e. Future commitments go; past history stays.
  delete from event_rsvps er
  using events e
  where er.event_id = e.id
    and er.user_id = v_uid
    and e.event_date > now();

  -- Open polls they haven't voted in: drop them from the eligible
  -- list so live polls don't wait on a deleted account. Votes cast
  -- and closed-poll snapshots are history and stay untouched.
  select coalesce(array_agg(pev.poll_id), '{}') into v_open_poll_ids
  from poll_eligible_voters pev
  join polls p on p.id = pev.poll_id
  where pev.user_id = v_uid
    and (p.closes_at is null or p.closes_at > now())
    and not exists (
      select 1 from poll_votes pv
      where pv.poll_id = pev.poll_id and pv.user_id = v_uid
    );

  delete from poll_eligible_voters
  where user_id = v_uid and poll_id = any(v_open_poll_ids);

  -- Mirror the auto-close rule: with the leaver out of the list,
  -- a poll where everyone remaining has voted closes now.
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

  -- 4f. Their devices and inbox.
  delete from fcm_tokens where user_id = v_uid;
  delete from notifications where user_id = v_uid;

  -- 4g. Anonymize the tombstone. Tasks, comments, attachments,
  -- events, announcements, polls, votes and log entries keep their
  -- references and now render as "Former member".
  update profiles
  set full_name = 'Former member',
      email = '',
      personal_email = null,
      deleted_at = now()
  where id = v_uid;

  -- 4h. Remove the login itself. Sessions, refresh tokens,
  -- identities and MFA factors cascade inside the auth schema.
  delete from auth.users where id = v_uid;
end;
$$;

-- ── 5. Privileges (same conventions as 20260702000000) ────────

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

revoke execute on function public.transfer_presidency(uuid, uuid)
  from public, anon;
grant execute on function public.transfer_presidency(uuid, uuid)
  to authenticated;

revoke execute on function public.relink_directors_on_vp_approval()
  from public, anon, authenticated;

-- Housekeeping flagged by the security advisor: trigger functions
-- added after the 20260702 hardening pass were never EXECUTE-revoked
-- like the rest. Triggers run as the table owner, so this does not
-- affect them.
revoke execute on function public.close_poll_when_all_voted()
  from public, anon, authenticated;
revoke execute on function public.log_poll_created()
  from public, anon, authenticated;
revoke execute on function public.log_task_assigned()
  from public, anon, authenticated;
