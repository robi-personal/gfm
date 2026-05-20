import { OAuth2Client } from "google-auth-library";

import { env } from "../../config/env";

// Google's OIDC tokens are issued by https://accounts.google.com — the OAuth2Client
// fetches and caches the public keys automatically when verifyIdToken is called.
const client = new OAuth2Client();

/**
 * Verify the OIDC token Google Pub/Sub attaches to push deliveries.
 * Pub/Sub signs tokens with the configured service-account email; we check the
 * audience matches our endpoint and that the issuer is Google.
 */
export async function verifyPubsubOidcToken(token: string): Promise<void> {
  if (!env.FORMS_PUBSUB_AUDIENCE) {
    throw new Error("FORMS_PUBSUB_AUDIENCE not configured");
  }

  const ticket = await client.verifyIdToken({
    idToken: token,
    audience: env.FORMS_PUBSUB_AUDIENCE,
  });

  const payload = ticket.getPayload();
  if (!payload) throw new Error("Empty OIDC payload");
  if (payload.iss !== "https://accounts.google.com" && payload.iss !== "accounts.google.com") {
    throw new Error(`Unexpected issuer: ${payload.iss}`);
  }
}
