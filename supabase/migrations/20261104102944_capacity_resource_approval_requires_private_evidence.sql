do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  'if v_future_availability_count=0 then raise exception using errcode=''23514'',message=''No future availability window remains for this resource'';end if;',
  'if v_future_availability_count=0 then raise exception using errcode=''23514'',message=''No future availability window remains for this resource'';end if;
  if jsonb_typeof(v_old_state#>''{metadata,document_paths}'') is distinct from ''array'' then
   raise exception using errcode=''23514'',message=''Cannot approve: private resource evidence documents are required'';
  end if;
  if jsonb_array_length(v_old_state#>''{metadata,document_paths}'')<1 then
   raise exception using errcode=''23514'',message=''Cannot approve: upload at least one supporting resource document'';
  end if;
  if exists(select 1 from jsonb_array_elements_text(v_old_state#>''{metadata,document_paths}'') as d(path)
   where d.path !~ (''^''||v_org_id::text||''/[0-9a-fA-F-]{36}/capacity-[0-9a-fA-F-]{36}\.(pdf|png|jpe?g)$'')
    or not exists(select 1 from storage.objects so where so.bucket_id=''krim-partner-verification'' and so.name=d.path)) then
   raise exception using errcode=''23514'',message=''Cannot approve: one or more resource evidence files are missing or invalid in private storage'';
  end if;');
 if position('private resource evidence documents are required' in v_def)=0 then raise exception 'Failed to add resource evidence approval gate';end if;
 execute v_def;
end $$;