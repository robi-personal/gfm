export interface QuotaProduct {
  productId: string;
  productType: "subscription" | "topup" | "free";
  displayName: string;
  quotaAmount: number;
  updatedAt: Date;
}
