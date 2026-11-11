-- Non-destructive profile-name update RPC.
-- Run in the Supabase SQL Editor if saving a name reports that
-- public.update_my_profile(text) is missing or cannot be executed.

create or replace function public.update_my_profile(new_display_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_name text := trim(coalesce(new_display_name, ''));
begin
  if auth.uid() is null then
    raise exception 'Sign in to update your profile.';
  end if;

  if normalized_name = '' or char_length(normalized_name) > 80 then
    raise exception 'Name must be between 1 and 80 characters.';
  end if;

  update public.profiles
  set display_name = normalized_name,
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found.';
  end if;
end;
$$;

revoke all on function public.update_my_profile(text) from public, anon;
grant execute on function public.update_my_profile(text) to authenticated;

notify pgrst, 'reload schema';
