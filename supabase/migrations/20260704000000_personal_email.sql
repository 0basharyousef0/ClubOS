-- ============================================================
-- ClubOS — Personal email on profiles
-- The university email (auth email) is what members log in with;
-- the personal email is an extra contact channel shown in the
-- directory. Collected at signup via user metadata.
-- ============================================================

alter table public.profiles
  add column if not exists personal_email text;

-- Store the personal email passed in signUp() metadata. NULL for
-- accounts created before this migration.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email, personal_email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    nullif(trim(new.raw_user_meta_data->>'personal_email'), '')
  );
  return new;
end;
$$;
