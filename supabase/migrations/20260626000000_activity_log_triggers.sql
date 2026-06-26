-- Phase 10: Activity log auto-population.
--
-- These triggers record an entry in public.activity_log whenever a member acts:
-- starting/completing a task, RSVPing to an event, posting an announcement, or
-- voting in a poll. The club President reads this feed (see the
-- activity_log_select RLS policy in the initial schema).
--
-- Every function is SECURITY DEFINER so it can write to activity_log regardless
-- of the actor's own RLS, and each insert is wrapped in an exception handler so
-- a logging failure can NEVER roll back the member's actual action.

-- Tasks: log when a task moves to in_progress (started) or complete (completed).
create or replace function public.log_task_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_action text;
begin
  -- Only react to real status transitions made by a known user.
  if v_actor is null or new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'complete' then
    v_action := 'task_completed';
  elsif new.status = 'in_progress' then
    v_action := 'task_started';
  else
    return new;
  end if;

  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id, v_actor, v_action,
      jsonb_build_object('title', new.title, 'task_id', new.id)
    );
  exception when others then
    null; -- never block the task update
  end;

  return new;
end;
$$;

drop trigger if exists trg_log_task_status on public.tasks;
create trigger trg_log_task_status
  after update of status on public.tasks
  for each row execute function public.log_task_status_change();

-- Announcements: log each new post, attributed to its author.
create or replace function public.log_announcement_posted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.activity_log (club_id, user_id, action_type, details)
    values (
      new.club_id, new.posted_by, 'announcement_posted',
      jsonb_build_object('title', new.title, 'announcement_id', new.id)
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists trg_log_announcement on public.announcements;
create trigger trg_log_announcement
  after insert on public.announcements
  for each row execute function public.log_announcement_posted();

-- Event RSVPs: the club and title live on the parent event, so look them up.
create or replace function public.log_event_rsvp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club uuid;
  v_title text;
begin
  select club_id, title into v_club, v_title
  from public.events where id = new.event_id;

  if v_club is not null then
    begin
      insert into public.activity_log (club_id, user_id, action_type, details)
      values (
        v_club, new.user_id, 'event_rsvp',
        jsonb_build_object('title', v_title, 'event_id', new.event_id)
      );
    exception when others then
      null;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_event_rsvp on public.event_rsvps;
create trigger trg_log_event_rsvp
  after insert on public.event_rsvps
  for each row execute function public.log_event_rsvp();

-- Poll votes: the club and title live on the parent poll, so look them up.
create or replace function public.log_poll_vote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club uuid;
  v_title text;
begin
  select club_id, title into v_club, v_title
  from public.polls where id = new.poll_id;

  if v_club is not null then
    begin
      insert into public.activity_log (club_id, user_id, action_type, details)
      values (
        v_club, new.user_id, 'poll_vote',
        jsonb_build_object('title', v_title, 'poll_id', new.poll_id)
      );
    exception when others then
      null;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_poll_vote on public.poll_votes;
create trigger trg_log_poll_vote
  after insert on public.poll_votes
  for each row execute function public.log_poll_vote();
