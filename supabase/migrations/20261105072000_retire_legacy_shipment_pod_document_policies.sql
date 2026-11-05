-- Legacy shipment_pod_documents is empty and its policies only reference
-- shipment_requests/partners. The canonical POD workflow uses krim_pod_records
-- plus private krim-driver-evidence. Lock the retired legacy table.
drop policy if exists "Customers can view their shipment PODs" on public.shipment_pod_documents;
drop policy if exists "Partners can upload their shipment PODs" on public.shipment_pod_documents;
drop policy if exists "Partners can view their shipment PODs" on public.shipment_pod_documents;
revoke all on table public.shipment_pod_documents from anon, authenticated;
