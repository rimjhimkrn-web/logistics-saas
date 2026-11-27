-- Allow signed-in users to manage only their own account preference document.
-- Existing SELECT/INSERT/UPDATE RLS policies constrain user_id to auth.uid().
GRANT SELECT, INSERT, UPDATE ON TABLE public.krim_user_app_preferences TO authenticated;
REVOKE ALL ON TABLE public.krim_user_app_preferences FROM anon;
