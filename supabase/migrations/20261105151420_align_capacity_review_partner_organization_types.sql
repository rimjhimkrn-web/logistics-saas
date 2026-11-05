-- Keep capacity registration and privileged review aligned with all supported
-- registered-business partner organization types. Expose the type in the
-- administrator queue so its UI mirrors the server-side approval predicate.

DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure)
    INTO v_def;

  IF position('not in (''partner'',''carrier'',''warehouse'',''forwarder'')' in v_def)=0 THEN
    RAISE EXCEPTION 'Expected capacity review organization-type guard was not found';
  END IF;

  v_def := replace(
    v_def,
    'not in (''partner'',''carrier'',''warehouse'',''forwarder'')',
    'not in (''partner'',''carrier'',''warehouse'',''forwarder'',''logistics_provider'',''warehouse_operator'')'
  );
  EXECUTE v_def;

  SELECT pg_get_functiondef('public.krim_admin_list_capacity_resources()'::regprocedure)
    INTO v_def;

  IF position('''organization_status'',o.status,' in v_def)=0 THEN
    RAISE EXCEPTION 'Expected capacity queue organization status field was not found';
  END IF;

  v_def := replace(
    v_def,
    '''organization_status'',o.status,',
    '''organization_status'',o.status, ''organization_type'',coalesce(o.organization_type_code,o.organization_type),'
  );
  EXECUTE v_def;
END $$;
