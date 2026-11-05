-- Reject null decision, code and status values explicitly in compliance review input.
DO $patch$
DECLARE d text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_review_partner_compliance(bigint,text,jsonb,text,timestamp with time zone)'::regprocedure) INTO d;
 d:=replace(d,'if p_organization_id is null or v_decision not in (''approved'',''rejected'',''on_hold'') then',
                 'if p_organization_id is null or v_decision is null or v_decision not in (''approved'',''rejected'',''on_hold'') then');
 d:=replace(d,'if not (v_code=any(v_required)) or v_code=any(v_seen) then',
                 'if v_code is null or not (v_code=any(v_required)) or v_code=any(v_seen) then');
 d:=replace(d,'if v_status not in (''verified'',''not_applicable'',''pending'',''rejected'') then',
                 'if v_status is null or v_status not in (''verified'',''not_applicable'',''pending'',''rejected'') then');
 IF position('v_decision is null' in d)=0 OR position('v_status is null' in d)=0 OR position('v_code is null' in d)=0 THEN
   RAISE EXCEPTION 'Compliance validation hardening did not apply completely';
 END IF;
 EXECUTE d;
END
$patch$;
