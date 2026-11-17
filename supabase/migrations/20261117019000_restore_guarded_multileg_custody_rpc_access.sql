-- Restore authenticated access to guarded multi-leg custody transfer RPCs.
-- Both routines enforce caller identity, exact partner organisation membership,
-- permission checks, adjacent-leg bindings, and receiving capacity checks.
GRANT EXECUTE ON FUNCTION public.krim_create_leg_custody_transfer(
  bigint,bigint,jsonb,text,text,text,text,text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_respond_to_leg_custody_transfer(
  bigint,boolean,text
) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_create_leg_custody_transfer(
  bigint,bigint,jsonb,text,text,text,text,text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.krim_respond_to_leg_custody_transfer(
  bigint,boolean,text
) FROM PUBLIC, anon;
