-- Drop existing table if it exists
DROP TABLE IF EXISTS driver_verifications CASCADE;

-- Create driver_verifications table
CREATE TABLE driver_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    id_number TEXT NOT NULL,
    license_number TEXT NOT NULL,
    id_card_url TEXT NOT NULL,
    license_url TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_driver_verifications_user_id ON driver_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_driver_verifications_status ON driver_verifications(status);

-- Enable Row Level Security
ALTER TABLE driver_verifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own verification" ON driver_verifications;
DROP POLICY IF EXISTS "Users can insert own verification" ON driver_verifications;
DROP POLICY IF EXISTS "Users can update own verification if not approved" ON driver_verifications;

-- Create policies
-- Allow users to view their own verification
CREATE POLICY "Users can view own verification"
    ON driver_verifications
    FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to insert their own verification
CREATE POLICY "Users can insert own verification"
    ON driver_verifications
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own verification if it's not approved
CREATE POLICY "Users can update own verification if not approved"
    ON driver_verifications
    FOR UPDATE
    USING (
        auth.uid() = user_id 
        AND status != 'approved'
    );

-- Drop existing function and trigger if they exist
DROP TRIGGER IF EXISTS update_driver_verifications_updated_at ON driver_verifications;
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_driver_verifications_updated_at
    BEFORE UPDATE ON driver_verifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Drop existing notification function and trigger if they exist
DROP TRIGGER IF EXISTS verification_status_change_notification ON driver_verifications;
DROP FUNCTION IF EXISTS notify_verification_status_change();

-- Create function to notify when verification status changes
CREATE OR REPLACE FUNCTION notify_verification_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM pg_notify(
            'verification_status_changed',
            json_build_object(
                'user_id', NEW.user_id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for status change notification
CREATE TRIGGER verification_status_change_notification
    AFTER UPDATE ON driver_verifications
    FOR EACH ROW
    EXECUTE FUNCTION notify_verification_status_change(); 