import { DevicePlatform, DeviceToken } from "../entities/device-token.entity";

export interface DeviceTokenRepository {
  /** Upsert: if token exists, reassign to userId and bump last_seen_at; else insert. */
  upsert(userId: number, fcmToken: string, platform: DevicePlatform): Promise<void>;

  /** Delete a specific device token. Used on sign-out from a single device. */
  deleteByToken(fcmToken: string): Promise<void>;

  /** All tokens for a user (push to multiple devices). */
  listByUserId(userId: number): Promise<DeviceToken[]>;

  /** Remove invalid tokens after FCM rejects them with NOT_REGISTERED. */
  deleteMany(fcmTokens: string[]): Promise<void>;
}
