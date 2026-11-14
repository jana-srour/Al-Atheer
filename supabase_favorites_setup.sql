-- Run in the Supabase SQL Editor to enable account-scoped favorites.
create table if not exists public.resource_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  resource_id bigint not null check (resource_id > 0),
  created_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);

alter table public.resource_favorites enable row level security;
revoke all on public.resource_favorites from public, anon, authenticated;
grant select, insert, update, delete on public.resource_favorites to authenticated;

drop policy if exists "Users can read their own favorites"
  on public.resource_favorites;
create policy "Users can read their own favorites"
  on public.resource_favorites
  for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Users can add their own favorites"
  on public.resource_favorites;
create policy "Users can add their own favorites"
  on public.resource_favorites
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Users can update their own favorites"
  on public.resource_favorites;
create policy "Users can update their own favorites"
  on public.resource_favorites
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users can remove their own favorites"
  on public.resource_favorites;
create policy "Users can remove their own favorites"
  on public.resource_favorites
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';
