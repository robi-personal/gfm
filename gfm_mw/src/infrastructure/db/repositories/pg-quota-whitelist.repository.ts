import { QuotaWhitelistEntry } from "../../../domain/entities/quota-whitelist-entry";
import { QuotaWhitelistRepository } from "../../../domain/repositories/quota-whitelist.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): QuotaWhitelistEntry {
  return {
    email:     row["email"]      as string,
    note:      row["note"]       as string | null,
    addedBy:   row["added_by"]   as string | null,
    createdAt: row["created_at"] as Date,
  };
}

export class PgQuotaWhitelistRepository implements QuotaWhitelistRepository {
  constructor(private readonly db: DbClient) {}

  async contains(email: string): Promise<boolean> {
    const { rowCount } = await this.db.query(
      "SELECT 1 FROM quota_whitelist WHERE email = LOWER($1)",
      [email],
    );
    return (rowCount ?? 0) > 0;
  }

  async getAll(): Promise<QuotaWhitelistEntry[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM quota_whitelist ORDER BY created_at DESC",
    );
    return rows.map(mapRow);
  }

  async add(
    email: string,
    note: string | null,
    addedBy: string | null,
  ): Promise<QuotaWhitelistEntry> {
    const { rows } = await this.db.query(
      `INSERT INTO quota_whitelist (email, note, added_by)
       VALUES (LOWER($1), $2, $3)
       ON CONFLICT (email) DO UPDATE SET note = EXCLUDED.note, added_by = EXCLUDED.added_by
       RETURNING *`,
      [email, note, addedBy],
    );
    return mapRow(rows[0]);
  }

  async remove(email: string): Promise<void> {
    await this.db.query(
      "DELETE FROM quota_whitelist WHERE email = LOWER($1)",
      [email],
    );
  }
}
