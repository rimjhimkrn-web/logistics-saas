-- A partner's corrected submission must reopen the same case and clear the old request.
do $migration$
declare
  v_definition text;
  v_original_case_update text := $old$
    UPDATE public.krim_partner_verification_cases
    SET submitted_by=v_user_id, submitted_at=now(),
        metadata=coalesce(metadata,'{}'::jsonb) || v_metadata, updated_at=now()
    WHERE id=v_case_id;
$old$;
  v_revised_case_update text := $new$
    UPDATE public.krim_partner_verification_cases
    SET status='open', decision=NULL, decision_reason=NULL,
        submitted_by=v_user_id, submitted_at=now(),
        completed_at=NULL,
        metadata=coalesce(metadata,'{}'::jsonb) || v_metadata, updated_at=now()
    WHERE id=v_case_id;
$new$;
  v_old_org text := $oldorg$
      partner_onboarding_status='submitted',
      partner_submitted_at=now(),
$oldorg$;
  v_new_org text := $neworg$
      partner_onboarding_status='submitted',
      partner_review_notes=NULL,
      partner_submitted_at=now(),
$neworg$;
begin
  select pg_get_functiondef('public.krim_submit_partner_onboarding_global_v2(text,text,text,text,text[],text,text,text,text,text,text,text,text,text)'::regprocedure)
    into v_definition;
  if position(v_original_case_update in v_definition)=0 then
    raise exception 'Expected partner verification case resubmission block was not found; refusing to patch';
  end if;
  if position(v_old_org in v_definition)=0 then
    raise exception 'Expected partner organization submission block was not found; refusing to patch';
  end if;
  v_definition := replace(v_definition,v_original_case_update,v_revised_case_update);
  v_definition := replace(v_definition,v_old_org,v_new_org);
  execute v_definition;
end
$migration$;
