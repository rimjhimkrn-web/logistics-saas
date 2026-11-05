-- The legacy pod-documents bucket has zero objects and zero document rows.
-- Its policies target legacy shipment_requests/partners tables; retire that upload/read path.
drop policy if exists "Customers can read their POD files" on storage.objects;
drop policy if exists "Partners can read their POD files" on storage.objects;
drop policy if exists "Partners can upload their POD files" on storage.objects;
