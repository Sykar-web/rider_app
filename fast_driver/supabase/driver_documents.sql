-- Run once in the shared Supabase SQL editor before testing document submission.
-- Documents are private. Clients can access only files in their own user folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('driver-documents', 'driver-documents', false, 10485760,
  array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

create policy "driver_documents_insert_own" on storage.objects for insert to authenticated
with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "driver_documents_select_own" on storage.objects for select to authenticated
using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "driver_documents_update_own" on storage.objects for update to authenticated
using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Application data is stored under auth.users.raw_user_meta_data.driver_application.
-- This is applicant-provided data, never a source of trusted approval/authorization.
-- Grant approval through a trusted admin workflow and enforce ride permissions
-- with server-owned roles/status and RLS before releasing onboarding to production.
