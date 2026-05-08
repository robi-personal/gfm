import crypto from "node:crypto";

// Canonicalize a JSON-shaped value: sort object keys recursively, no whitespace.
// Used for the request hash that backs idempotency cache lookups (api-contract.md §5.2).
function canonicalize(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map(canonicalize).join(",") + "]";
  }
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  const parts = keys.map((k) => JSON.stringify(k) + ":" + canonicalize(obj[k]));
  return "{" + parts.join(",") + "}";
}

export function hashRequestBody(body: unknown): string {
  return crypto.createHash("sha256").update(canonicalize(body)).digest("hex");
}
