-- FastRide design integration: run this complete file in Supabase SQL Editor.
-- Re-runnable additive setup for the shared profile and driver application.
-- Requires your existing FastRide profiles/rides/deliveries database.

-- FastRide: private, user-owned profile pictures. Safe to run again.
BEGIN;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_path text;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_avatar_own_folder' AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_avatar_own_folder
      CHECK (avatar_path IS NULL OR split_part(avatar_path, '/', 1) = id::text);
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-photos', 'profile-photos', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "FastRide own profile photo read" ON storage.objects;
CREATE POLICY "FastRide own profile photo read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
DROP POLICY IF EXISTS "FastRide own profile photo upload" ON storage.objects;
CREATE POLICY "FastRide own profile photo upload" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
DROP POLICY IF EXISTS "FastRide own profile photo delete" ON storage.objects;
CREATE POLICY "FastRide own profile photo delete" ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);

COMMIT;



-- FastRide: shared-account driver application. Run once in Supabase SQL Editor.
-- Approval is an administrator action; clients can only save/submit applications.
begin;
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists vehicle_plate text;
alter table public.profiles add column if not exists vehicle_type text;
create table if not exists public.driver_applications (
  user_id uuid primary key references auth.users(id) on delete cascade,
  details jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','pending','approved','rejected')),
  submitted_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.driver_applications enable row level security;
revoke all on public.driver_applications from anon, authenticated;
grant select on public.driver_applications to authenticated;
drop policy if exists "Read own driver application" on public.driver_applications;
create policy "Read own driver application" on public.driver_applications
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.save_driver_application(application_details jsonb, submit_application boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare
  applicant uuid := auth.uid();
  current_status text;
  doc text;
  profile_photo text;
begin
  if applicant is null then raise exception 'Sign in first'; end if;
  if jsonb_typeof(application_details) <> 'object' or octet_length(application_details::text) > 32768 then
    raise exception 'Invalid application';
  end if;
  -- Serialize saves/submission so concurrent requests cannot revert pending to draft.
  perform pg_advisory_xact_lock(hashtextextended(applicant::text, 0));
  select status into current_status from public.driver_applications where user_id = applicant for update;
  if current_status in ('pending','approved') then raise exception 'Application already submitted'; end if;
  for doc in select value from jsonb_each_text(coalesce(application_details->'documents','{}'::jsonb)) loop
    if split_part(doc,'/',1) <> applicant::text then raise exception 'Document belongs to another account'; end if;
  end loop;
  if submit_application then
    if coalesce(application_details->>'consent','false') <> 'true' then raise exception 'Confirm your application'; end if;
    foreach doc in array array['full_name','phone','email','home_area','licence_number','licence_expiry','make','model','year','colour','registration_number'] loop
      if nullif(btrim(application_details->>doc),'') is null then raise exception 'Missing required information'; end if;
    end loop;
    if application_details->>'vehicle_type' not in ('Motorcycle','Car','Van','Bus') then raise exception 'Invalid vehicle'; end if;
    if (application_details->>'year')::integer not between 1980 and extract(year from now())::integer + 1 then raise exception 'Invalid vehicle year'; end if;
    if (application_details->>'licence_expiry')::date < current_date then raise exception 'Licence expired'; end if;
    foreach doc in array array['National ID front','National ID back','Driving License','Vehicle Photo'] loop
      if not exists (select 1 from storage.objects where bucket_id = 'driver-documents' and name = application_details->'documents'->>doc) then
        raise exception 'Missing uploaded document';
      end if;
    end loop;
    select avatar_path into profile_photo from public.profiles where id = applicant;
    if profile_photo is null and not exists (
      select 1 from auth.users where id = applicant and coalesce(raw_user_meta_data->>'picture',raw_user_meta_data->>'driver_profile_photo','') <> ''
    ) and not exists (
      select 1 from storage.objects where bucket_id='driver-documents'
      and name=application_details->'documents'->>'Profile Photo'
      and (storage.foldername(name))[1]=applicant::text
    ) then raise exception 'Add a shared profile picture'; end if;
  end if;
  insert into public.driver_applications(user_id,details,status,submitted_at)
  values(applicant,application_details,case when submit_application then 'pending' else 'draft' end,case when submit_application then now() end)
  on conflict(user_id) do update set details=excluded.details,status=excluded.status,submitted_at=excluded.submitted_at,updated_at=now();
end $$;
revoke all on function public.save_driver_application(jsonb,boolean) from public, anon;
grant execute on function public.save_driver_application(jsonb,boolean) to authenticated;

-- Trusted approval endpoint: executable only by SQL Editor/service-role tooling.
create or replace function public.review_driver_application(applicant_id uuid, approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare application jsonb;
begin
  select details into application from public.driver_applications
    where user_id=applicant_id and status='pending' for update;
  if application is null then raise exception 'No pending application'; end if;
  if not exists(select 1 from public.profiles where id=applicant_id) then raise exception 'Missing shared profile'; end if;
  update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
    || jsonb_build_object('driver_approved',approve) where id=applicant_id;
  if approve then
    update public.profiles set role='driver',
      (vehicle_type,vehicle_plate) = (select v.vehicle_type,v.vehicle_plate from jsonb_populate_record(null::public.profiles,
        jsonb_build_object('vehicle_type',lower(application->>'vehicle_type'),'vehicle_plate',upper(application->>'registration_number'))) v)
      where id=applicant_id;
  end if;
  update public.driver_applications set status=case when approve then 'approved' else 'rejected' end,updated_at=now() where user_id=applicant_id;
end $$;
revoke all on function public.review_driver_application(uuid,boolean) from public,anon,authenticated;
grant execute on function public.review_driver_application(uuid,boolean) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('driver-documents','driver-documents',false,5242880,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do nothing;
drop policy if exists "Driver application own upload" on storage.objects;
create policy "Driver application own upload" on storage.objects for insert to authenticated
with check (bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Driver application own read" on storage.objects;
create policy "Driver application own read" on storage.objects for select to authenticated
using (bucket_id='driver-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
commit;

-- Review applications from the dashboard/SQL Editor with privileged access.
-- Grant approved users raw_app_meta_data.driver_approved=true via trusted admin
-- tooling only, then set driver_applications.status='approved'. Never store an
-- admin/service-role key in Flutter. A refreshed session enables driver mode.


