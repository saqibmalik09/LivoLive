-- User date of birth for profile edit screen.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS date_of_birth date;

COMMENT ON COLUMN public.users.date_of_birth IS
  'User birthday (yyyy-MM-dd), shown on edit profile.';
