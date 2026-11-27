export const EMAIL_OUTBOX_SELECT =
  "id,organization_id,recipient_type,recipient_reference,notification_type,subject,message,provider,idempotency_key,metadata,status";

export const ESSENTIAL_EMAIL_EVENT_TYPES = new Set([
  "shipment.created",
  "shipment.status_changed",
  "partner.assignment_offered",
  "partner.assignment_status_changed"
]);

export function isSupportedEssentialEmailEvent(value: unknown): boolean {
  return typeof value === "string" && ESSENTIAL_EMAIL_EVENT_TYPES.has(value);
}
