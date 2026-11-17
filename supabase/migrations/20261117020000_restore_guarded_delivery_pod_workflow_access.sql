-- Restore authenticated entry to guarded POD workflow.
-- Driver submission is bound to auth.uid(), active driver membership,
-- in-transit assignment and uploader-owned private evidence.
-- Admin review/list require AAL2 and platform admin permission internally.
GRANT EXECUTE ON FUNCTION public.krim_driver_submit_delivery_pod(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_admin_list_delivery_pods() TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_admin_review_delivery_pod(bigint,text,text) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_driver_submit_delivery_pod(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.krim_admin_list_delivery_pods() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.krim_admin_review_delivery_pod(bigint,text,text) FROM PUBLIC, anon;
