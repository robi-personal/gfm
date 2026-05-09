export interface User {
  id: number;
  googleSub: string;
  email: string;
  createdAt: Date;
  isPremium: boolean;
  aiFreeUsed: number;
  aiPremiumUsed: number;
  freeMonthResetAt: Date | null;
  premiumResetAt: Date | null;
  gracePeriodUntil: Date | null;
  youtubeMinutesUsed: number;
  youtubeMinutesResetAt: Date | null;
}
