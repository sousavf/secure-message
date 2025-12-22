-- Fix the messages_message_type_check constraint to allow FILE type
-- Run this against your PostgreSQL database

-- Drop the old constraint
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_message_type_check;

-- Add the new constraint with FILE included
ALTER TABLE messages ADD CONSTRAINT messages_message_type_check
    CHECK (message_type IN ('TEXT', 'STICKER', 'IMAGE', 'FILE'));
