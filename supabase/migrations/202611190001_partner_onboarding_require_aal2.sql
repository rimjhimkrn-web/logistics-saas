-- KRIM partner onboarding MFA enforcement
-- Target: KRIM Logistics staging project only.
-- Keep partner organization provisioning and account-mode selection available
-- during bootstrap; these create pending/non-commercial state. Require AAL2
-- for sensitive verification submission and private evidence uploads.
begin;

do $migration$
declare
  v_definition text;
  v_anchor text := $anchor$IF auth.uid() IS NULL THEN
   RAISE EXCEPTION USING errcode='28000', message='Authentication required';
 END IF;$anchor$;
  v_replacement text := $replacement$IF auth.uid() IS NULL THEN
   RAISE EXCEPTION USING errcode='28000', message='Authentication required';
 END IF;

 IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN
   RAISE EXCEPTION USING errcode='42501', message='Multi-factor authentication required before submitting partner verification';
 END IF;$replacement$;
begin
  select pg_get_functiondef(
    'public.krim_submit_partner_onboarding_global_multi_v1(text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb)'::regprocedure
  ) into v_definition;

  if position(v_anchor in v_definition) = 0 then
    raise exception 'Expected authentication guard not found; aborting without changing function';
  end if;

  if position('Multi-factor authentication required before submitting partner verification' in v_definition) = 0 then
    v_definition := replace(v_definition, v_anchor, v_replacement);
    execute v_definition;
  end if;
end
$migration$;

drop policy if exists krim_partner_verification_upload_require_aal2
  on storage.objects;

create policy krim_partner_verification_upload_require_aal2
  on storage.objects
  as restrictive
  for insert
  to authenticated
  with check (
    bucket_id = 'krim-partner-verification'
    and coalesce(auth.jwt()->>'aal','aal1') = 'aal2'
  );

commit;
