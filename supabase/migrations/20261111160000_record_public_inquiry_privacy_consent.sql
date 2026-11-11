-- Persist affirmative privacy consent with every new public enquiry.
-- Existing rows remain false/unknown; do not backfill historical consent.

alter table public.krim_public_contact_inquiries
  add column if not exists privacy_consent boolean not null default false,
  add column if not exists privacy_consent_at timestamptz,
  add column if not exists privacy_notice_version text;

create or replace function public.krim_submit_public_contact_inquiry(
  p_full_name text,
  p_email text,
  p_organization text,
  p_message text,
  p_source_page text
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_name text := btrim(p_full_name);
  v_email text := lower(btrim(p_email));
  v_org text := btrim(p_organization);
  v_message text := btrim(p_message);
  v_source text := case when p_source_page = 'krim-global-advertisement.html'
                        then 'krim-global-advertisement.html' else 'contact.html' end;
  v_recent_count integer;
  v_inquiry_id uuid;
  v_event_id uuid;
  v_outbox_id bigint;
  v_profile_id bigint;
  v_qualification_id bigint;
begin
  if length(v_name) < 2 or length(v_name) > 120
     or length(v_email) < 5 or length(v_email) > 254
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
     or length(v_org) < 2 or length(v_org) > 180
     or length(v_message) < 10 or length(v_message) > 5000 then
    raise exception using errcode = '22023', message = 'invalid_inquiry';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('krim-public-inquiry:' || v_email, 0));
  select count(*) into v_recent_count
  from public.krim_public_contact_inquiries
  where lower(email) = v_email
    and created_at >= now() - interval '1 hour';

  if v_recent_count >= 3 then
    return jsonb_build_object('rate_limited', true);
  end if;

  insert into public.krim_public_contact_inquiries
    (full_name, email, organization, message, source_page,
     privacy_consent, privacy_consent_at, privacy_notice_version)
  values (v_name, v_email, v_org, v_message, v_source,
          true, clock_timestamp(), '2026-11-11')
  returning id into v_inquiry_id;

  insert into public.krim_customer_acquisition_profiles
    (source_type, source_reference, discovery_slug, display_name,
     status, qualification_status, onboarding_status, metadata)
  values
    ('direct', v_inquiry_id::text, 'contact-' || replace(v_inquiry_id::text, '-', ''),
     v_org, 'engaged', 'pending', 'not_started',
     jsonb_build_object(
       'contact_name', v_name,
       'contact_email', v_email,
       'inquiry_id', v_inquiry_id,
       'source_page', v_source,
       'consent_status', 'recorded',
       'privacy_notice_version', '2026-11-11',
       'qualification_state', 'awaiting_review'
     ))
  returning id into v_profile_id;

  insert into public.krim_customer_acquisition_events
    (profile_id, event_type, source_type, event_reference, metadata)
  values
    (v_profile_id, 'discovered', 'direct', v_inquiry_id::text,
     jsonb_build_object('inquiry_id', v_inquiry_id, 'source_page', v_source,
                        'privacy_consent_recorded', true,
                        'privacy_notice_version', '2026-11-11'));

  insert into public.krim_customer_qualification_cases
    (customer_profile_id, qualification_level, status,
     qualification_reasons, missing_information, automated_result)
  values
    (v_profile_id, 'standard', 'pending',
     jsonb_build_array('Public enquiry received; service requirements not yet confirmed.'),
     jsonb_build_array('origin and destination', 'transport mode', 'cargo or service details', 'expected frequency or volume', 'required service date'),
     'awaiting_founder_review_and_customer_details')
  returning id into v_qualification_id;

  insert into public.krim_events
    (organization_id, entity_type, entity_id, event_type, source, payload, metadata)
  values
    (1, 'public_contact_inquiry', null, 'customer.inquiry.received', 'public_contact_form',
     jsonb_build_object('inquiry_id', v_inquiry_id, 'customer_profile_id', v_profile_id,
                        'qualification_case_id', v_qualification_id, 'source_page', v_source,
                        'privacy_consent_recorded', true,
                        'privacy_notice_version', '2026-11-11'),
     jsonb_build_object('notification_required', true))
  returning event_id into v_event_id;

  insert into public.krim_notification_outbox
    (event_id, organization_id, recipient_type, recipient_reference,
     notification_type, channel, priority, subject, message, payload,
     status, provider, idempotency_key, metadata)
  values
    (v_event_id, 1, 'founder', 'primary', 'customer_inquiry_received',
     'telegram', 10, 'New KRIM customer enquiry',
     left('New KRIM customer enquiry' ||
       E'\nName: ' || v_name ||
       E'\nEmail: ' || v_email ||
       E'\nOrganization: ' || v_org ||
       E'\nSource: ' || v_source ||
       E'\nInquiry ID: ' || v_inquiry_id::text ||
       E'\nQualification case: ' || v_qualification_id::text, 3500),
     jsonb_build_object('inquiry_id', v_inquiry_id,
                        'customer_profile_id', v_profile_id,
                        'qualification_case_id', v_qualification_id),
     'pending', 'telegram', 'customer-inquiry:' || v_inquiry_id::text,
     jsonb_build_object('delivery_mode', 'immediate_edge_dispatch',
                        'privacy_consent_recorded', true,
                        'privacy_notice_version', '2026-11-11'))
  returning id into v_outbox_id;

  return jsonb_build_object(
    'success', true,
    'inquiry_id', v_inquiry_id,
    'customer_profile_id', v_profile_id,
    'qualification_case_id', v_qualification_id,
    'event_id', v_event_id,
    'outbox_id', v_outbox_id
  );
end;
$function$;
