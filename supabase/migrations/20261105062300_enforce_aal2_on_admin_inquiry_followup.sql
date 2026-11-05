-- Every authenticated platform-admin write RPC requires server-side AAL2.
create or replace function public.krim_admin_schedule_inquiry_followup(
  p_inquiry_id uuid,
  p_note text,
  p_follow_up_at timestamp with time zone
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_followup_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='AAL2 multi-factor authentication is required';
  end if;
  if not coalesce(public.krim_has_permission(v_user_id,1,'admin.platform'),false) then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_inquiry_id is null
     or p_note is null
     or length(btrim(p_note)) < 1
     or length(btrim(p_note)) > 2000 then
    raise exception using errcode='22023', message='Valid inquiry and follow-up note are required';
  end if;
  if p_follow_up_at is not null and p_follow_up_at < now() then
    raise exception using errcode='22023', message='Follow-up time must be in the future';
  end if;
  if not exists(select 1 from public.krim_public_contact_inquiries where id=p_inquiry_id) then
    raise exception using errcode='P0002', message='Inquiry not found';
  end if;

  insert into public.krim_inquiry_followups
    (inquiry_id,note,follow_up_at,outcome,created_by)
  values
    (p_inquiry_id,btrim(p_note),p_follow_up_at,'pending',v_user_id)
  returning id into v_followup_id;

  update public.krim_public_contact_inquiries
  set status='in_review'
  where id=p_inquiry_id and status='new';

  return jsonb_build_object(
    'success',true,
    'followup_id',v_followup_id,
    'inquiry_id',p_inquiry_id,
    'outcome','pending',
    'customer_contact_sent',false
  );
end;
$function$;
