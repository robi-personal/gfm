import { User } from "../entities/user.entity";

export interface UserRepository {
  findByGoogleSub(googleSub: string): Promise<User | null>;
  findById(id: number): Promise<User | null>;
  upsert(googleSub: string, email: string): Promise<User>;
  incrementFreeUsed(userId: number): Promise<void>;
  incrementPremiumUsed(userId: number): Promise<void>;
  resetFreeQuotaIfExpired(userId: number): Promise<void>;

  // YouTube minute cap
  incrementYoutubeMinutes(userId: number, minutes: number): Promise<void>;
  resetYoutubeMinutesIfNeeded(userId: number): Promise<void>;

  // RevenueCat event handlers
  setPremium(userId: number, premiumResetAt: Date): Promise<void>;
  renewPremium(userId: number, premiumResetAt: Date): Promise<void>;
  setGracePeriod(userId: number, gracePeriodUntil: Date): Promise<void>;
  revokePremium(userId: number, eventExpiresAt: Date): Promise<void>;
  revokeImmediately(userId: number): Promise<void>;
  updateProductChange(userId: number, isPremium: boolean, newResetAt: Date): Promise<void>;
  transferFrom(googleSubs: string[]): Promise<void>;
  transferTo(googleSubs: string[]): Promise<void>;
}
