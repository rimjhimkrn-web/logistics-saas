create or replace function public.krim_admin_review_capacity_resource(p_resource_id bigint,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_user_id uuid:=auth.uid();v_decision text:=lower(nullif(btrim(coalesce(p_decision,'')),''));v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_org_id bigint;v_org_mode text;v_org_status text;v_org_lifecycle text;v_org_verification text;v_org_compliance text;
 v_transport_mode_id bigint;v_old_state jsonb;v_new_state jsonb;v_availability_count integer;
begin
 if v_user_id is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception using errcode='42501',message='Multi-factor authentication required';end if;
 if not private.krim_has_permission(v_user_id,1::bigint,'admin.platform') then raise exception using errcode='42501',message='Platform administrator permission required';end if;
 if p_resource_id is null or v_decision is null or v_decision not in ('approved','rejected') then raise exception using errcode='22023',message='Choose a resource and an approved or rejected decision';end if;
 if v_reason is null or char_length(v_reason)<5 or char_length(v_reason)>1000 then raise exception using errcode='22023',message='Review evidence or rejection reason must contain 5–1000 characters';end if;
 select r.organization_id,r.transport_mode_id,o.partner_account_mode,o.status,o.partner_lifecycle_status,o.partner_verification_status,o.partner_compliance_status,
  jsonb_build_object('resource_id',r.id,'status',r.status,'metadata',r.metadata)
 into v_org_id,v_transport_mode_id,v_org_mode,v_org_status,v_org_lifecycle,v_org_verification,v_org_compliance,v_old_state
 from public.krim_capacity_resources r join public.krim_organizations o on o.id=r.organization_id where r.id=p_resource_id for update of r,o;
 if v_org_id is null then raise exception using errcode='P0002',message='Capacity resource not found';end if;
 if not (v_old_state->>'status'='pending_review' or v_old_state#>>'{metadata,verification_state}'='pending_review') then raise exception using errcode='55000',message='Only pending-review resources can be decided';end if;
 perform 1 from public.krim_partner_capacity_availability a where a.capacity_resource_id=p_resource_id for update;
 get diagnostics v_availability_count=row_count;
 if v_availability_count=0 then raise exception using errcode='23514',message='No availability record is attached to this resource';end if;
 if v_decision='approved' then
  if coalesce(v_org_mode,'')<>'registered_business' or coalesce(v_org_status,'')<>'active'
   or coalesce(v_org_lifecycle,'') not in ('active','verified')
   or coalesce(v_org_verification,'') not in ('verified','approved')
   or coalesce(v_org_compliance,'') not in ('clear','compliant','approved','verified','not_required','not_applicable') then
   raise exception using errcode='23514',message='Partner organisation must be active, verified and compliant before resource approval';
  end if;
  if not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_org_id and c.transport_mode_id=v_transport_mode_id and c.active=true and c.verification_status='verified') then
   raise exception using errcode='23514',message='A separately approved capability for this transport mode is required before resource approval';
  end if;
 end if;
 update public.krim_capacity_resources set status=case when v_decision='approved' then 'available' else 'rejected' end,
  metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('verification_state',case when v_decision='approved' then 'verified' else 'rejected' end,
   'reviewed_at',now(),'reviewed_by',v_user_id,'review_decision',v_decision,'review_reason',v_reason),updated_at=now() where id=p_resource_id;
 update public.krim_partner_capacity_availability set status=case when v_decision='approved' then 'available' else 'unavailable' end,
  metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('verification_state',case when v_decision='approved' then 'verified' else 'rejected' end,
   'reviewed_at',now(),'reviewed_by',v_user_id,'review_decision',v_decision,'review_reason',v_reason),updated_at=now() where capacity_resource_id=p_resource_id;
 v_new_state:=jsonb_build_object('resource_id',p_resource_id,'resource_status',case when v_decision='approved' then 'available' else 'rejected' end,
  'availability_status',case when v_decision='approved' then 'available' else 'unavailable' end,'decision',v_decision,'reason',v_reason);
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user_id,v_org_id,'partner.capacity_resource.reviewed','capacity_resource',p_resource_id::text,'capacity_resource_review',
  jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);
 return jsonb_build_object('resource_id',p_resource_id,'organization_id',v_org_id,'decision',v_decision,'resource_status',v_new_state->>'resource_status','availability_status',v_new_state->>'availability_status');
end;
$function$;

create or replace function public.krim_admin_review_partner_capability(p_capability_id bigint,p_decision text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_user_id uuid:=auth.uid();v_decision text:=lower(nullif(btrim(p_decision),''));v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_org_id bigint;v_org_mode text;v_org_status text;v_org_lifecycle text;v_org_verification text;v_org_compliance text;
 v_cap_status text;v_old_state jsonb;v_new_state jsonb;
begin
 if v_user_id is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception using errcode='42501',message='Multi-factor authentication required';end if;
 if not private.krim_has_permission(v_user_id,1::bigint,'admin.platform') then raise exception using errcode='42501',message='Platform administrator permission required';end if;
 if p_capability_id is null or v_decision is null or v_decision not in ('approved','rejected') then raise exception using errcode='22023',message='Choose a capability and an approved or rejected decision';end if;
 if v_decision='rejected' and (v_reason is null or char_length(v_reason)<5) then raise exception using errcode='22023',message='A rejection reason of at least 5 characters is required';end if;
 if char_length(coalesce(v_reason,''))>1000 then raise exception using errcode='22023',message='Review notes must be 1000 characters or fewer';end if;
 select c.organization_id,c.verification_status,o.partner_account_mode,o.status,o.partner_lifecycle_status,o.partner_verification_status,o.partner_compliance_status,
  jsonb_build_object('capability_id',c.id,'active',c.active,'verification_status',c.verification_status,'metadata',c.metadata)
 into v_org_id,v_cap_status,v_org_mode,v_org_status,v_org_lifecycle,v_org_verification,v_org_compliance
 from public.krim_partner_capabilities c join public.krim_organizations o on o.id=c.organization_id where c.id=p_capability_id for update of c,o;
 if v_org_id is null then raise exception using errcode='P0002',message='Partner capability not found';end if;
 if v_cap_status<>'pending' then raise exception using errcode='55000',message='Only pending capabilities can be reviewed';end if;
 if v_decision='approved' and (coalesce(v_org_mode,'')<>'registered_business' or coalesce(v_org_status,'')<>'active'
  or coalesce(v_org_lifecycle,'')<>'active' or coalesce(v_org_verification,'')<>'verified' or coalesce(v_org_compliance,'')<>'compliant') then
  raise exception using errcode='23514',message='The partner organisation must be an approved, verified and compliant registered business before a capability can be activated';
 end if;
 update public.krim_partner_capabilities set verification_status=case when v_decision='approved' then 'verified' else 'rejected' end,active=(v_decision='approved'),
  metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('reviewed_at',now(),'reviewed_by',v_user_id,'review_decision',v_decision,'review_reason',v_reason) where id=p_capability_id;
 v_new_state:=jsonb_build_object('capability_id',p_capability_id,'active',(v_decision='approved'),'verification_status',case when v_decision='approved' then 'verified' else 'rejected' end,'decision',v_decision,'reason',v_reason);
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user_id,v_org_id,'partner.capability.reviewed','partner_capability',p_capability_id::text,'partner_capability_review',jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);
 return jsonb_build_object('capability_id',p_capability_id,'organization_id',v_org_id,'decision',v_decision,'active',(v_decision='approved'),'verification_status',case when v_decision='approved' then 'verified' else 'rejected' end);
end;
$function$;
revoke all on function public.krim_admin_review_capacity_resource(bigint,text,text) from public,anon,authenticated;
grant execute on function public.krim_admin_review_capacity_resource(bigint,text,text) to authenticated;
revoke all on function public.krim_admin_review_partner_capability(bigint,text,text) from public,anon,authenticated;
grant execute on function public.krim_admin_review_partner_capability(bigint,text,text) to authenticated;