export type DevicePlatform = "ios" | "android";

export interface DeviceToken {
  id: number;
  userId: number;
  fcmToken: string;
  platform: DevicePlatform;
  createdAt: Date;
  lastSeenAt: Date;
}
