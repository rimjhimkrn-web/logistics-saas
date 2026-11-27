import { EMAIL_OUTBOX_SELECT, isSupportedEssentialEmailEvent } from "./policy.ts";

Deno.test("email outbox projection includes notification_type", () => {
  if (!EMAIL_OUTBOX_SELECT.split(",").includes("notification_type")) {
    throw new Error("notification_type must be selected before allowlist validation");
  }
});

Deno.test("allows only supported essential event types", () => {
  const allowed = [
    "shipment.created",
    "shipment.status_changed",
    "partner.assignment_offered",
    "partner.assignment_status_changed"
  ];
  for (const eventType of allowed) {
    if (!isSupportedEssentialEmailEvent(eventType)) {
      throw new Error(`Expected ${eventType} to be allowed`);
    }
  }
});

Deno.test("rejects unsupported, missing and non-string event types", () => {
  for (const eventType of ["marketing.campaign", "unknown.event", "", null, undefined, 42]) {
    if (isSupportedEssentialEmailEvent(eventType)) {
      throw new Error(`Unexpectedly allowed event type: ${String(eventType)}`);
    }
  }
});
