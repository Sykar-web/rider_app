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
