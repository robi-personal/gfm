import { QuotaProduct } from "../entities/quota-product";

export interface QuotaProductRepository {
  getAll(): Promise<QuotaProduct[]>;
  getById(productId: string): Promise<QuotaProduct | null>;
  setAmount(productId: string, quotaAmount: number): Promise<void>;
}
