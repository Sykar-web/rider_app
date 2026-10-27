-- FastDriver design-board setup. Run in the same Supabase project as FastRide.
-- Re-runnable; existing passenger tables and policies are retained.
begin;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('driver-documents','driver-documents',false,10485760,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists driver_documents_insert_own on storage.objects;
create policy driver_documents_insert_own on storage.objects for insert to authenticated
with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists driver_documents_select_own on storage.objects;
create policy driver_documents_select_own on storage.objects for select to authenticated
using(bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists driver_documents_update_own on storage.objects;
create policy driver_documents_update_own on storage.objects for update to authenticated
using(bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists driver_documents_delete_own on storage.objects;
create policy driver_documents_delete_own on storage.objects for delete to authenticated
using(bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);

alter table public.deliveries add column if not exists started_at timestamptz;

create table if not exists public.driver_support_tickets (
 id uuid primary key default gen_random_uuid(),
 driver_id uuid not null references auth.users(id) on delete cascade,
 message text not null check(char_length(message) between 10 and 2000),
 status text not null default 'open' check(status in ('open','resolved')),
 created_at timestamptz not null default now()
);
alter table public.driver_support_tickets enable row level security;
revoke all on public.driver_support_tickets from anon;
grant select,insert on public.driver_support_tickets to authenticated;
revoke update,delete on public.driver_support_tickets from authenticated;
drop policy if exists driver_support_insert_own on public.driver_support_tickets;
create policy driver_support_insert_own on public.driver_support_tickets for insert to authenticated
with check(driver_id=(select auth.uid()) and status='open');
drop policy if exists driver_support_select_own on public.driver_support_tickets;
create policy driver_support_select_own on public.driver_support_tickets for select to authenticated
using(driver_id=(select auth.uid()));
create index if not exists driver_support_owner_date on public.driver_support_tickets(driver_id,created_at desc);

-- Serialize claims across rides AND deliveries, including separate devices.
create or replace function public.fastdriver_one_active_job()
returns trigger language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 if new.status::text not in ('accepted','arriving','picked_up','in_progress') then return new; end if;
 owner_id := case when tg_table_name='rides' then (to_jsonb(new)->>'driver_id')::uuid else (to_jsonb(new)->>'courier_id')::uuid end;
 if owner_id is null then raise exception 'Active job requires a driver'; end if;
 if tg_op='INSERT' or (to_jsonb(old)->>'status')='requested' then
   if not exists(select 1 from auth.users u where u.id=owner_id and u.raw_app_meta_data @> '{"driver_approved":true}'::jsonb) then
     raise exception 'Driver approval is required before accepting jobs';
   end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,0));
 if exists(select 1 from public.rides r where r.driver_id=owner_id and r.status::text in ('accepted','arriving','in_progress') and (tg_table_name<>'rides' or r.id<>new.id))
 or exists(select 1 from public.deliveries d where d.courier_id=owner_id and d.status::text in ('accepted','picked_up','in_progress') and (tg_table_name<>'deliveries' or d.id<>new.id))
 then raise exception 'Complete the active trip before accepting another job'; end if;
 return new;
end $$;
revoke all on function public.fastdriver_one_active_job() from public;
drop trigger if exists fastdriver_one_active_ride on public.rides;
create trigger fastdriver_one_active_ride before insert or update on public.rides for each row execute function public.fastdriver_one_active_job();
drop trigger if exists fastdriver_one_active_delivery on public.deliveries;
create trigger fastdriver_one_active_delivery before insert or update on public.deliveries for each row execute function public.fastdriver_one_active_job();

-- Publish matching/tracking changes for both apps when the realtime publication exists.
do $$
declare t text;
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  foreach t in array array['rides','deliveries','profiles'] loop
   if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
    execute format('alter publication supabase_realtime add table public.%I',t);
   end if;
  end loop;
 end if;
end $$;

commit;
-- Driver approval and access must still be controlled by trusted admin/app_metadata
-- and existing rides/deliveries/profiles RLS. This script does not auto-approve accounts.
-- Support staff read/reply requires your admin dashboard/service backend.



