import * as admin from "firebase-admin";

import { env } from "../../config/env";
import { logger } from "../logger";

let app: admin.app.App | null = null;
let initialized = false;

export function initFcm(): void {
  if (initialized) return;
  initialized = true;

  const raw = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    logger.warn("fcm_disabled_no_service_account");
    return;
  }

  try {
    // Accept either raw JSON or base64-encoded JSON (recommended in .env to
    // sidestep newline-escaping issues with the private_key field).
    const decoded = raw.trim().startsWith("{")
      ? raw
      : Buffer.from(raw, "base64").toString("utf-8");
    const credentials = JSON.parse(decoded) as admin.ServiceAccount;
    app = admin.initializeApp({
      credential: admin.credential.cert(credentials),
    });
    logger.info("fcm_initialized");
  } catch (err) {
    logger.error({ err }, "fcm_init_failed");
  }
}

export interface SendResult {
  /** Tokens that FCM reports as no longer valid (NOT_REGISTERED) — caller should remove from DB. */
  invalidTokens: string[];
  successCount: number;
  failureCount: number;
}

/** Send the same notification to N device tokens. Returns invalid tokens for cleanup. */
export async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<SendResult> {
  if (!app || tokens.length === 0) {
    return { invalidTokens: [], successCount: 0, failureCount: 0 };
  }

  const response = await admin.messaging(app).sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "form_responses",
      },
    },
  });

  const invalidTokens: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success && r.error) {
      const code = r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[i]);
      } else {
        logger.warn({ code, token: tokens[i].slice(0, 12) }, "fcm_send_failed");
      }
    }
  });

  return {
    invalidTokens,
    successCount: response.successCount,
    failureCount: response.failureCount,
  };
}
