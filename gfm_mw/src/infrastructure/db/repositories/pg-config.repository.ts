import { ConfigRepository } from "../../../domain/repositories/config.repository";
import { DbClient } from "../postgres";

export class PgConfigRepository implements ConfigRepository {
  constructor(private readonly db: DbClient) {}

  async getAll(): Promise<Record<string, string>> {
    const { rows } = await this.db.query("SELECT key, value FROM server_config");
    const out: Record<string, string> = {};
    for (const row of rows) {
      out[row["key"] as string] = row["value"] as string;
    }
    return out;
  }

  async set(key: string, value: string): Promise<void> {
    await this.db.query(
      `INSERT INTO server_config (key, value)
       VALUES ($1, $2)
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      [key, value],
    );
  }
}
