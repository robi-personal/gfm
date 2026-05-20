import { FormWatch } from "../../../domain/entities/form-watch.entity";
import { FormWatchRepository } from "../../../domain/repositories/form-watch.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): FormWatch {
  return {
    watchId:   row["watch_id"]   as string,
    formId:    row["form_id"]    as string,
    userId:    row["user_id"]    as number,
    formTitle: row["form_title"] as string,
    createdAt: row["created_at"] as Date,
    expiresAt: row["expires_at"] as Date,
  };
}

export class PgFormWatchRepository implements FormWatchRepository {
  constructor(private readonly db: DbClient) {}

  async upsert(watch: Omit<FormWatch, "createdAt">): Promise<void> {
    // ON CONFLICT (form_id, user_id) — if the user re-toggles, replace the watch_id and expiry.
    await this.db.query(
      `INSERT INTO form_watches (watch_id, form_id, user_id, form_title, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (form_id, user_id)
       DO UPDATE SET watch_id   = EXCLUDED.watch_id,
                     form_title = EXCLUDED.form_title,
                     expires_at = EXCLUDED.expires_at`,
      [watch.watchId, watch.formId, watch.userId, watch.formTitle, watch.expiresAt],
    );
  }

  async deleteByWatchId(watchId: string): Promise<void> {
    await this.db.query("DELETE FROM form_watches WHERE watch_id = $1", [watchId]);
  }

  async listByFormId(formId: string): Promise<FormWatch[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM form_watches WHERE form_id = $1 AND expires_at > NOW()",
      [formId],
    );
    return rows.map(mapRow);
  }

  async isMessageProcessed(messageId: string): Promise<boolean> {
    const { rowCount } = await this.db.query(
      "SELECT 1 FROM processed_pubsub_messages WHERE message_id = $1",
      [messageId],
    );
    return (rowCount ?? 0) > 0;
  }

  async markMessageProcessed(messageId: string): Promise<void> {
    await this.db.query(
      "INSERT INTO processed_pubsub_messages (message_id) VALUES ($1) ON CONFLICT DO NOTHING",
      [messageId],
    );
  }
}
