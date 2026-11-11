-- Shared Internet Archive credentials for administrator uploads.
-- Run in the Supabase SQL Editor. This creates a new table and does not alter
-- or delete existing app data.

create table if not exists public.archive_credentials (
  id boolean primary key default true check (id),
  access_key text not null,
  secret_key text not null,
  updated_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now()
);

alter table public.archive_credentials enable row level security;
revoke all on public.archive_credentials from public, anon, authenticated;
grant select, insert, update on public.archive_credentials to authenticated;

drop policy if exists "Admins can manage archive credentials"
  on public.archive_credentials;
create policy "Admins can manage archive credentials"
  on public.archive_credentials
  for all
  to authenticated
  using ((select public.is_current_user_admin()))
  with check ((select public.is_current_user_admin()));

notify pgrst, 'reload schema';
