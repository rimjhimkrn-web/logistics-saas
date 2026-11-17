-- Enable authenticated invocation of the protected partner service-area review queue.
-- Both SECURITY DEFINER functions independently enforce AAL2 and admin.platform permission.
grant execute on function public.krim_admin_list_partner_service_areas() to authenticated;
grant execute on function public.krim_admin_review_partner_service_area(bigint, text, text) to authenticated;
