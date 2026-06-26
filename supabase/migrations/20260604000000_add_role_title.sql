-- Add optional role_title column to store specific position names
-- e.g. "VP Finance", "Director of Marketing"
ALTER TABLE user_club_roles ADD COLUMN IF NOT EXISTS role_title text;
