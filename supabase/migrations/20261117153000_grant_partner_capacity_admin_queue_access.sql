-- Enable the protected lane-aware capacity review queue for signed-in platform administrators.
-- The SECURITY DEFINER RPCs enforce AAL2 and admin.platform internally.
-- The lower-level list RPC stays unexposed and is called by the lane-aware wrapper.
grant execute on function public.krim_admin_list_capacity_resources_lane_aware() to authenticated;
grant execute on function public.krim_admin_review_capacity_resource(bigint, text, text) to authenticated;
