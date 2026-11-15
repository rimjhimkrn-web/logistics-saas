ALTER TABLE public.krim_driver_tracking_sessions
  ADD COLUMN IF NOT EXISTS consent_notice_text text,
  ADD COLUMN IF NOT EXISTS consent_notice_sha256 text,
  ADD COLUMN IF NOT EXISTS consent_language text NOT NULL DEFAULT 'en-IN';

ALTER TABLE public.krim_driver_tracking_sessions
  DROP CONSTRAINT IF EXISTS krim_driver_tracking_sessions_consent_notice_pair_check;

ALTER TABLE public.krim_driver_tracking_sessions
  ADD CONSTRAINT krim_driver_tracking_sessions_consent_notice_pair_check
  CHECK (
    (consent_notice_text IS NULL AND consent_notice_sha256 IS NULL)
    OR (
      NULLIF(BTRIM(consent_notice_text), '') IS NOT NULL
      AND consent_notice_sha256 ~ '^[0-9a-f]{64}$'
    )
  );

COMMENT ON COLUMN public.krim_driver_tracking_sessions.consent_notice_text
  IS 'Exact server-controlled location-sharing notice shown to the driver at consent time; null only for legacy sessions.';
COMMENT ON COLUMN public.krim_driver_tracking_sessions.consent_notice_sha256
  IS 'SHA-256 digest of consent_notice_text for audit and notice-version integrity.';
COMMENT ON COLUMN public.krim_driver_tracking_sessions.consent_language
  IS 'Language/locale of the exact archived location-sharing consent notice.';
