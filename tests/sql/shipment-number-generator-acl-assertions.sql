-- Run only after the proposed shipment-number generator ACL migration
-- has been applied to an isolated test/staging database.
\set ON_ERROR_STOP on

do $$
begin
  if has_function_privilege('anon','public.generate_krim_shipment_number()','EXECUTE') then
    raise exception 'anon must not execute shipment-number generator';
  end if;
  if has_function_privilege('authenticated','public.generate_krim_shipment_number()','EXECUTE') is not true then
    raise exception 'authenticated must retain shipment-number default execution';
  end if;
  if has_function_privilege('service_role','public.generate_krim_shipment_number()','EXECUTE') is not true then
    raise exception 'service_role must retain shipment-number default execution';
  end if;
  if has_sequence_privilege('anon','public.krim_shipment_number_seq','USAGE') then
    raise exception 'anon must not consume shipment-number sequence';
  end if;
  if has_sequence_privilege('anon','public.krim_shipment_number_seq','UPDATE') then
    raise exception 'anon must not advance shipment-number sequence';
  end if;
  if has_sequence_privilege('authenticated','public.krim_shipment_number_seq','USAGE') is not true then
    raise exception 'authenticated must retain sequence usage';
  end if;
  if has_sequence_privilege('authenticated','public.krim_shipment_number_seq','UPDATE') is not true then
    raise exception 'authenticated must retain sequence update';
  end if;
  if has_sequence_privilege('service_role','public.krim_shipment_number_seq','USAGE') is not true then
    raise exception 'service_role must retain sequence usage';
  end if;
  if has_sequence_privilege('service_role','public.krim_shipment_number_seq','UPDATE') is not true then
    raise exception 'service_role must retain sequence update';
  end if;
end $$;
