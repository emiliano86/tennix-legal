-- Fix RLS policies per il bucket avatars
-- Permette agli utenti autenticati di caricare, aggiornare e leggere i propri avatar

-- 1. Assicurati che il bucket avatars esista e sia pubblico
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];

-- 2. Elimina le vecchie policy se esistono
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;

-- 3. Crea le nuove policy corrette

-- Policy per permettere agli utenti di caricare i propri avatar
CREATE POLICY "Users can upload their own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per permettere agli utenti di aggiornare i propri avatar
CREATE POLICY "Users can update their own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per permettere agli utenti di eliminare i propri avatar
CREATE POLICY "Users can delete their own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per permettere a tutti di vedere gli avatar (lettura pubblica)
CREATE POLICY "Avatars are publicly accessible"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- 4. Verifica che le policy siano attive
DO $$
BEGIN
  RAISE NOTICE '✅ Policy per bucket avatars configurate correttamente!';
  RAISE NOTICE 'Gli utenti possono ora:';
  RAISE NOTICE '  - Caricare avatar nella propria cartella (user_id/)';
  RAISE NOTICE '  - Aggiornare i propri avatar';
  RAISE NOTICE '  - Eliminare i propri avatar';
  RAISE NOTICE '  - Vedere tutti gli avatar (pubblicamente)';
END $$;
