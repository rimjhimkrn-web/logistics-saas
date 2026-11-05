-- Rejected/restricted partner organizations are not eligible for another compliance review.
DO $$
DECLARE d text; old_filter text:=$old$o.partner_lifecycle_status in ('approved','active','restricted')$old$;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_list_partner_compliance_reviews()'::regprocedure) INTO d;
 IF position('o.partner_lifecycle_status in (''approved'',''active'')' in d)=0 THEN
  IF position(old_filter in d)=0 THEN RAISE EXCEPTION 'Restricted lifecycle filter not found'; END IF;
  d:=replace(d,old_filter,$new$o.partner_lifecycle_status in ('approved','active')$new$);
  EXECUTE d;
 END IF;
END $$;