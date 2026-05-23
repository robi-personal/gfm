import { WebhookEventRepository } from "../../../domain/repositories/webhook-event.repository";
import { DbClient } from "../postgres";

export interface OrphanWebhookEvent {
  eventId: string;
  eventType: string;
  rawPayload: unknown;
}

export class PgWebhookEventRepository implements WebhookEventRepository {
  constructor(private readonly db: DbClient) {}

  async existsById(eventId: string): Promise<boolean> {
    const { rowCount } = await this.db.query(
      "SELECT 1 FROM webhook_events WHERE event_id = $1",
      [eventId],
    );
    return (rowCount ?? 0) > 0;
  }

  async insertIfAbsent(
    eventId: string,
    eventType: string,
    userId: number | null,
    rawPayload: unknown,
  ): Promise<{ inserted: boolean }> {
    const { rowCount } = await this.db.query(
      `INSERT INTO webhook_events (event_id, event_type, user_id, raw_payload)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (event_id) DO NOTHING`,
      [eventId, eventType, userId, rawPayload],
    );
    return { inserted: (rowCount ?? 0) > 0 };
  }

  // ── Orphan replay (purchase-flow.md §7 #6) ─────────────────────────────────
  // Returns events that were stored with user_id=NULL because the user did
  // not yet exist when the webhook arrived. Ordered by processed_at so
  // replay applies them in arrival order.
  async listOrphanedForGoogleSub(googleSub: string): Promise<OrphanWebhookEvent[]> {
    const { rows } = await this.db.query(
      `SELECT event_id, event_type, raw_payload
         FROM webhook_events
        WHERE user_id IS NULL
          AND raw_payload -> 'event' ->> 'app_user_id' = $1
        ORDER BY processed_at ASC`,
      [googleSub],
    );
    return rows.map((r) => ({
      eventId:    r["event_id"] as string,
      eventType:  r["event_type"] as string,
      rawPayload: r["raw_payload"],
    }));
  }

  async claimForUser(eventId: string, userId: number): Promise<void> {
    await this.db.query(
      "UPDATE webhook_events SET user_id = $2 WHERE event_id = $1 AND user_id IS NULL",
      [eventId, userId],
    );
  }
}
