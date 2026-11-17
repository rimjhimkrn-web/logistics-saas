-- Enable authenticated invocation of admin partner review queues.
-- Both functions independently enforce AAL2 and admin.platform permission.
grant execute on function public.krim_admin_list_partner_verification_cases() to authenticated;
grant execute on function public.krim_admin_list_partner_capabilities() to authenticated;
