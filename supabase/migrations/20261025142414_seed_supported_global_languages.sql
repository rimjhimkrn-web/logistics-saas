-- Seed the two interface languages currently supported by the public KRIM experience.
-- Other languages must remain inactive until translations are actually implemented and verified.
INSERT INTO public.krim_languages (language_code, language_name, native_name, is_rtl, is_active)
VALUES
  ('en', 'English', 'English', false, true),
  ('hi', 'Hindi', 'हिन्दी', false, true)
ON CONFLICT (language_code) DO UPDATE
SET language_name = EXCLUDED.language_name,
    native_name = EXCLUDED.native_name,
    is_rtl = EXCLUDED.is_rtl,
    is_active = EXCLUDED.is_active;
