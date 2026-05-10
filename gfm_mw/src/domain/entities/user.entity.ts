export interface User {
  id: number;
  googleSub: string;
  email: string;
  createdAt: Date;
  isPremium: boolean;
  quotaBalance: number;
  freeQuotaResetAt: Date | null;
  subscriptionProductId: string | null;
  gracePeriodUntil: Date | null;
  youtubeMinutesUsed: number;
  youtubeMinutesResetAt: Date | null;
}
