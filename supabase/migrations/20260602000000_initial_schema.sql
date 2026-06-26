-- ============================================================
-- ClubOS — Initial Schema Migration
-- ============================================================

create extension if not exists "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

create table public.clubs (
  id uuid primary key default uuid_generate_v4(),
  name text unique not null,
  constitution_content text,
  created_at timestamptz default now()
);

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text not null,
  created_at timestamptz default now()
);

create table public.user_club_roles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles on delete cascade,
  club_id uuid not null references public.clubs on delete cascade,
  role text not null check (role in ('president', 'vice_president', 'director')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  approved_by uuid references public.profiles,
  created_at timestamptz default now(),
  unique (user_id, club_id)
);

create table public.tasks (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs on delete cascade,
  title text not null,
  description text,
  assigned_to uuid references public.profiles,
  assigned_by uuid references public.profiles,
  due_date date,
  urgency text default 'normal' check (urgency in ('low', 'normal', 'high')),
  status text default 'not_started' check (status in ('not_started', 'in_progress', 'complete')),
  created_at timestamptz default now()
);

create table public.task_comments (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid not null references public.tasks on delete cascade,
  user_id uuid not null references public.profiles,
  content text not null,
  created_at timestamptz default now()
);

create table public.task_attachments (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid not null references public.tasks on delete cascade,
  file_url text not null,
  file_name text not null,
  uploaded_by uuid not null references public.profiles,
  created_at timestamptz default now()
);

create table public.events (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs on delete cascade,
  title text not null,
  description text,
  event_date timestamptz not null,
  created_by uuid not null references public.profiles,
  created_at timestamptz default now()
);

create table public.event_rsvps (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid not null references public.events on delete cascade,
  user_id uuid not null references public.profiles,
  created_at timestamptz default now(),
  unique (event_id, user_id)
);

create table public.announcements (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs on delete cascade,
  title text not null,
  content text not null,
  posted_by uuid not null references public.profiles,
  created_at timestamptz default now()
);

create table public.polls (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs on delete cascade,
  title text not null,
  description text,
  created_by uuid not null references public.profiles,
  audience text not null check (audience in ('all', 'vps_only', 'directors_only')),
  closes_at timestamptz,
  created_at timestamptz default now()
);

create table public.poll_options (
  id uuid primary key default uuid_generate_v4(),
  poll_id uuid not null references public.polls on delete cascade,
  text text not null
);

create table public.poll_votes (
  id uuid primary key default uuid_generate_v4(),
  poll_id uuid not null references public.polls on delete cascade,
  option_id uuid not null references public.poll_options on delete cascade,
  user_id uuid not null references public.profiles,
  created_at timestamptz default now(),
  unique (poll_id, user_id)
);

create table public.activity_log (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid not null references public.clubs on delete cascade,
  user_id uuid not null references public.profiles,
  action_type text not null,
  details jsonb,
  created_at timestamptz default now()
);

create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles on delete cascade,
  club_id uuid references public.clubs on delete cascade,
  type text not null,
  message text not null,
  read boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- GRANT TABLE ACCESS TO AUTHENTICATED ROLE
-- ============================================================

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.clubs enable row level security;
alter table public.profiles enable row level security;
alter table public.user_club_roles enable row level security;
alter table public.tasks enable row level security;
alter table public.task_comments enable row level security;
alter table public.task_attachments enable row level security;
alter table public.events enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.announcements enable row level security;
alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;
alter table public.activity_log enable row level security;
alter table public.notifications enable row level security;

-- PROFILES
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

create policy "profiles_insert" on public.profiles
  for insert to authenticated with check (id = auth.uid());

create policy "profiles_update" on public.profiles
  for update to authenticated using (id = auth.uid());

-- CLUBS: anyone authenticated can read (needed for join dropdown)
create policy "clubs_select" on public.clubs
  for select to authenticated using (true);

create policy "clubs_insert" on public.clubs
  for insert to authenticated with check (true);

create policy "clubs_update" on public.clubs
  for update to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = clubs.id and user_id = auth.uid()
      and role = 'president' and status = 'approved'
    )
  );

create policy "clubs_delete" on public.clubs
  for delete to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = clubs.id and user_id = auth.uid()
      and role = 'president' and status = 'approved'
    )
  );

-- USER_CLUB_ROLES
create policy "ucr_select" on public.user_club_roles
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.user_club_roles ucr2
      where ucr2.club_id = user_club_roles.club_id
      and ucr2.user_id = auth.uid()
      and ucr2.status = 'approved'
    )
  );

create policy "ucr_insert" on public.user_club_roles
  for insert to authenticated with check (user_id = auth.uid());

create policy "ucr_update" on public.user_club_roles
  for update to authenticated using (
    exists (
      select 1 from public.user_club_roles ucr2
      where ucr2.club_id = user_club_roles.club_id
      and ucr2.user_id = auth.uid()
      and ucr2.role = 'president' and ucr2.status = 'approved'
    )
  );

create policy "ucr_delete" on public.user_club_roles
  for delete to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.user_club_roles ucr2
      where ucr2.club_id = user_club_roles.club_id
      and ucr2.user_id = auth.uid()
      and ucr2.role = 'president' and ucr2.status = 'approved'
    )
  );

-- TASKS
create policy "tasks_select" on public.tasks
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id and user_id = auth.uid() and status = 'approved'
    )
  );

create policy "tasks_insert" on public.tasks
  for insert to authenticated with check (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

create policy "tasks_update" on public.tasks
  for update to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id and user_id = auth.uid() and status = 'approved'
      and (role in ('president', 'vice_president') or auth.uid() = tasks.assigned_to)
    )
  );

create policy "tasks_delete" on public.tasks
  for delete to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = tasks.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

-- TASK COMMENTS
create policy "task_comments_select" on public.task_comments
  for select to authenticated using (
    exists (
      select 1 from public.tasks t
      join public.user_club_roles ucr on ucr.club_id = t.club_id
      where t.id = task_comments.task_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

create policy "task_comments_insert" on public.task_comments
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.tasks t
      join public.user_club_roles ucr on ucr.club_id = t.club_id
      where t.id = task_comments.task_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

-- TASK ATTACHMENTS
create policy "task_attachments_select" on public.task_attachments
  for select to authenticated using (
    exists (
      select 1 from public.tasks t
      join public.user_club_roles ucr on ucr.club_id = t.club_id
      where t.id = task_attachments.task_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

create policy "task_attachments_insert" on public.task_attachments
  for insert to authenticated with check (
    uploaded_by = auth.uid()
    and exists (
      select 1 from public.tasks t
      join public.user_club_roles ucr on ucr.club_id = t.club_id
      where t.id = task_attachments.task_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

-- EVENTS
create policy "events_select" on public.events
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = events.club_id and user_id = auth.uid() and status = 'approved'
    )
  );

create policy "events_insert" on public.events
  for insert to authenticated with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.user_club_roles
      where club_id = events.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

create policy "events_update" on public.events
  for update to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = events.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

create policy "events_delete" on public.events
  for delete to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = events.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

-- EVENT RSVPS
create policy "event_rsvps_select" on public.event_rsvps
  for select to authenticated using (
    exists (
      select 1 from public.events e
      join public.user_club_roles ucr on ucr.club_id = e.club_id
      where e.id = event_rsvps.event_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

create policy "event_rsvps_insert" on public.event_rsvps
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.events e
      join public.user_club_roles ucr on ucr.club_id = e.club_id
      where e.id = event_rsvps.event_id
      and ucr.user_id = auth.uid()
      and ucr.role in ('vice_president', 'director') and ucr.status = 'approved'
    )
  );

create policy "event_rsvps_delete" on public.event_rsvps
  for delete to authenticated using (user_id = auth.uid());

-- ANNOUNCEMENTS
create policy "announcements_select" on public.announcements
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = announcements.club_id and user_id = auth.uid() and status = 'approved'
    )
  );

create policy "announcements_insert" on public.announcements
  for insert to authenticated with check (
    posted_by = auth.uid()
    and exists (
      select 1 from public.user_club_roles
      where club_id = announcements.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

create policy "announcements_delete" on public.announcements
  for delete to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = announcements.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

-- POLLS
create policy "polls_select" on public.polls
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles ucr
      where ucr.club_id = polls.club_id and ucr.user_id = auth.uid() and ucr.status = 'approved'
      and (
        polls.audience = 'all'
        or (polls.audience = 'vps_only' and ucr.role in ('president', 'vice_president'))
        or (polls.audience = 'directors_only' and ucr.role = 'director')
      )
    )
  );

create policy "polls_insert" on public.polls
  for insert to authenticated with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.user_club_roles
      where club_id = polls.club_id and user_id = auth.uid()
      and role in ('president', 'vice_president') and status = 'approved'
    )
  );

create policy "polls_delete" on public.polls
  for delete to authenticated using (
    created_by = auth.uid()
    or exists (
      select 1 from public.user_club_roles
      where club_id = polls.club_id and user_id = auth.uid()
      and role = 'president' and status = 'approved'
    )
  );

-- POLL OPTIONS
create policy "poll_options_select" on public.poll_options
  for select to authenticated using (
    exists (
      select 1 from public.polls p
      join public.user_club_roles ucr on ucr.club_id = p.club_id
      where p.id = poll_options.poll_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

create policy "poll_options_insert" on public.poll_options
  for insert to authenticated with check (
    exists (
      select 1 from public.polls p
      join public.user_club_roles ucr on ucr.club_id = p.club_id
      where p.id = poll_options.poll_id
      and ucr.user_id = auth.uid()
      and ucr.role in ('president', 'vice_president') and ucr.status = 'approved'
    )
  );

-- POLL VOTES
create policy "poll_votes_select" on public.poll_votes
  for select to authenticated using (
    exists (
      select 1 from public.polls p
      join public.user_club_roles ucr on ucr.club_id = p.club_id
      where p.id = poll_votes.poll_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
    )
  );

create policy "poll_votes_insert" on public.poll_votes
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.polls p
      join public.user_club_roles ucr on ucr.club_id = p.club_id
      where p.id = poll_votes.poll_id
      and ucr.user_id = auth.uid() and ucr.status = 'approved'
      and (
        p.audience = 'all'
        or (p.audience = 'vps_only' and ucr.role in ('president', 'vice_president'))
        or (p.audience = 'directors_only' and ucr.role = 'director')
      )
    )
  );

-- ACTIVITY LOG
create policy "activity_log_select" on public.activity_log
  for select to authenticated using (
    exists (
      select 1 from public.user_club_roles
      where club_id = activity_log.club_id and user_id = auth.uid()
      and role = 'president' and status = 'approved'
    )
  );

create policy "activity_log_insert" on public.activity_log
  for insert to authenticated with check (
    exists (
      select 1 from public.user_club_roles
      where club_id = activity_log.club_id and user_id = auth.uid() and status = 'approved'
    )
  );

-- NOTIFICATIONS
create policy "notifications_select" on public.notifications
  for select to authenticated using (user_id = auth.uid());

create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (true);

create policy "notifications_update" on public.notifications
  for update to authenticated using (user_id = auth.uid());
