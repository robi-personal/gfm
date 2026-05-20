import { DevicePlatform, DeviceToken } from "../../../domain/entities/device-token.entity";
import { DeviceTokenRepository } from "../../../domain/repositories/device-token.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): DeviceToken {
  return {
    id:         row["id"]            as number,
    userId:     row["user_id"]       as number,
    fcmToken:   row["fcm_token"]     as string,
    platform:   row["platform"]      as DevicePlatform,
    createdAt:  row["created_at"]    as Date,
    lastSeenAt: row["last_seen_at"]  as Date,
  };
}

export class PgDeviceTokenRepository implements DeviceTokenRepository {
  constructor(private readonly db: DbClient) {}

  async upsert(userId: number, fcmToken: string, platform: DevicePlatform): Promise<void> {
    await this.db.query(
      `INSERT INTO device_tokens (user_id, fcm_token, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (fcm_token)
       DO UPDATE SET user_id = EXCLUDED.user_id,
                     platform = EXCLUDED.platform,
                     last_seen_at = NOW()`,
      [userId, fcmToken, platform],
    );
  }

  async deleteByToken(fcmToken: string): Promise<void> {
    await this.db.query("DELETE FROM device_tokens WHERE fcm_token = $1", [fcmToken]);
  }

  async listByUserId(userId: number): Promise<DeviceToken[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM device_tokens WHERE user_id = $1",
      [userId],
    );
    return rows.map(mapRow);
  }

  async deleteMany(fcmTokens: string[]): Promise<void> {
    if (fcmTokens.length === 0) return;
    await this.db.query(
      "DELETE FROM device_tokens WHERE fcm_token = ANY($1::text[])",
      [fcmTokens],
    );
  }
}
