-- Phase 8: per-device FCM token storage.
-- A user can be signed in on multiple devices, so tokens are 1-user-to-many.
-- The token itself is unique (a device token maps to exactly one user); if a
-- device is re-used by another account, the upsert reassigns its user_id.

create table if not exists public.fcm_tokens (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles on delete cascade,
  token text not null unique,
  platform text,
  updated_at timestamptz default now()
);

create index if not exists fcm_tokens_user_id_idx
  on public.fcm_tokens (user_id);

alter table public.fcm_tokens enable row level security;

grant select, insert, update, delete on public.fcm_tokens to authenticated;

-- Users manage only their own device tokens.
drop policy if exists "fcm_tokens_select" on public.fcm_tokens;
create policy "fcm_tokens_select" on public.fcm_tokens
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "fcm_tokens_insert" on public.fcm_tokens;
create policy "fcm_tokens_insert" on public.fcm_tokens
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "fcm_tokens_update" on public.fcm_tokens;
create policy "fcm_tokens_update" on public.fcm_tokens
  for update to authenticated using (user_id = auth.uid());

drop policy if exists "fcm_tokens_delete" on public.fcm_tokens;
create policy "fcm_tokens_delete" on public.fcm_tokens
  for delete to authenticated using (user_id = auth.uid());
