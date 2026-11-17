import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { readBoundedJson } from "./bounded-json.ts";

function requestFromBytes(bytes: Uint8Array, headers = new Headers()): Request {
  return new Request("https://example.test/contact", {
    method: "POST",
    headers,
    body: new ReadableStream<Uint8Array>({
      start(controller) {
        // Split into chunks to exercise streaming enforcement.
        const midpoint = Math.floor(bytes.length / 2);
        controller.enqueue(bytes.slice(0, midpoint));
        controller.enqueue(bytes.slice(midpoint));
        controller.close();
      }
    }),
    // A custom stream is not automatically assigned a Content-Length.
    duplex: "half"
  } as RequestInit);
}

Deno.test("accepts a valid JSON body exactly at 9,000 bytes", async () => {
  const raw = JSON.stringify("x".repeat(8998));
  assertEquals(new TextEncoder().encode(raw).length, 9000);
  assertEquals(await readBoundedJson(requestFromBytes(new TextEncoder().encode(raw))), "x".repeat(8998));
});

Deno.test("rejects an oversized streamed body without Content-Length", async () => {
  const raw = JSON.stringify("x".repeat(8999));
  await assertRejects(
    () => readBoundedJson(requestFromBytes(new TextEncoder().encode(raw))),
    RangeError,
    "too large"
  );
});

Deno.test("rejects an oversized declared Content-Length before reading", async () => {
  const headers = new Headers({ "content-length": "9001" });
  await assertRejects(
    () => readBoundedJson(requestFromBytes(new TextEncoder().encode("{}"), headers)),
    RangeError,
    "too large"
  );
});

Deno.test("rejects malformed JSON", async () => {
  await assertRejects(
    () => readBoundedJson(requestFromBytes(new TextEncoder().encode("{"))),
    SyntaxError
  );
});

Deno.test("rejects invalid UTF-8", async () => {
  await assertRejects(
    () => readBoundedJson(requestFromBytes(new Uint8Array([0xc3, 0x28]))),
    TypeError
  );
});
