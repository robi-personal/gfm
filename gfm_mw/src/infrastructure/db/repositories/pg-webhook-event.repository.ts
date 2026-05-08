import { WebhookEventRepository } from "../../../domain/repositories/webhook-event.repository";
import { DbClient } from "../postgres";

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
}
