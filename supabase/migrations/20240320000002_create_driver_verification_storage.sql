-- This migration is now handled through the Supabase dashboard
-- Please follow the instructions in the README.md file for setting up storage 

-- Switch to supabase_admin role
SET ROLE supabase_admin;

-- Create storage bucket for driver verifications
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-verifications', 'driver-verifications', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all verification documents" ON storage.objects;

-- Create policy to allow users to upload their own verification documents
CREATE POLICY "Users can upload their own verification documents"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'driver-verifications' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Create policy to allow users to view their own verification documents
CREATE POLICY "Users can view their own verification documents"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'driver-verifications' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Create policy to allow admins to view all verification documents
CREATE POLICY "Admins can view all verification documents"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'driver-verifications' AND
    EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
);

-- Switch back to postgres role
SET ROLE postgres; 