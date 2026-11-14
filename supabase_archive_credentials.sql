-- Per-admin Internet Archive credentials for administrator uploads.
-- Run in the Supabase SQL Editor. Existing shared credentials are migrated to
-- the administrator account that saved them.

create table if not exists public.archive_credentials (
  user_id uuid primary key references auth.users (id) on delete cascade,
  access_key text not null,
  secret_key text not null,
  updated_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now()
);

alter table public.archive_credentials
  add column if not exists user_id uuid references auth.users (id) on delete cascade;

-- Migrate rows created by the original single shared-credential schema.
update public.archive_credentials
set user_id = updated_by
where user_id is null;

alter table public.archive_credentials
  alter column user_id set not null;

do $$
declare
  primary_key_name text;
  primary_key_definition text;
begin
  select constraint_row.conname, pg_get_constraintdef(constraint_row.oid)
    into primary_key_name, primary_key_definition
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.archive_credentials'::regclass
    and constraint_row.contype = 'p';

  if primary_key_name is not null
      and primary_key_definition <> 'PRIMARY KEY (user_id)' then
    execute format(
      'alter table public.archive_credentials drop constraint %I',
      primary_key_name
    );
    primary_key_name := null;
  end if;

  if primary_key_name is null then
    alter table public.archive_credentials
      add constraint archive_credentials_pkey primary key (user_id);
  end if;
end;
$$;

alter table public.archive_credentials enable row level security;
revoke all on public.archive_credentials from public, anon, authenticated;
grant select, insert, update on public.archive_credentials to authenticated;

drop policy if exists "Admins can manage archive credentials"
  on public.archive_credentials;
create policy "Admins can manage archive credentials"
  on public.archive_credentials
  for all
  to authenticated
  using (
    user_id = (select auth.uid())
    and (select public.is_current_user_admin())
  )
  with check (
    user_id = (select auth.uid())
    and (select public.is_current_user_admin())
  );

notify pgrst, 'reload schema';
