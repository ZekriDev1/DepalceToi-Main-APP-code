-- Add is_admin column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Create an index for faster admin checks
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_admin ON user_profiles(is_admin);

-- Update existing policies to use the new column
DROP POLICY IF EXISTS "Admins can view all verifications" ON driver_verifications;
DROP POLICY IF EXISTS "Admins can update verification status" ON driver_verifications;

-- Recreate the admin policies
CREATE POLICY "Admins can view all verifications"
    ON driver_verifications
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.is_admin = true
        )
    );

CREATE POLICY "Admins can update verification status"
    ON driver_verifications
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.is_admin = true
        )
    ); 