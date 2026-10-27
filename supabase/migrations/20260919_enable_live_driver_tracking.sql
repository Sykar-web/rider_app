-- FastRide / FastDriver live driver tracking.
-- Run once in the Supabase SQL Editor.

begin;

alter table public.profiles
  add column if not exists current_lat double precision,
  add column if not exists current_lng double precision,
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen timestamptz;

alter table public.profiles replica identity full;

do $migration$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'authenticated_users_can_read_driver_tracking'
  ) then
    create policy authenticated_users_can_read_driver_tracking
      on public.profiles
      for select
      to authenticated
      using (auth.uid() = id or role = 'driver');
  end if;
end
$migration$;

commit;

select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename = 'profiles';
