import { QuotaProduct } from "../../../domain/entities/quota-product";
import { QuotaProductRepository } from "../../../domain/repositories/quota-product.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): QuotaProduct {
  return {
    productId:   row["product_id"]   as string,
    productType: row["product_type"] as "subscription" | "topup" | "free",
    displayName: row["display_name"] as string,
    quotaAmount: row["quota_amount"] as number,
    updatedAt:   row["updated_at"]   as Date,
  };
}

export class PgQuotaProductRepository implements QuotaProductRepository {
  constructor(private readonly db: DbClient) {}

  async getAll(): Promise<QuotaProduct[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM quota_products ORDER BY product_type, display_name",
    );
    return rows.map(mapRow);
  }

  async getById(productId: string): Promise<QuotaProduct | null> {
    const { rows } = await this.db.query(
      "SELECT * FROM quota_products WHERE product_id = $1",
      [productId],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async setAmount(productId: string, quotaAmount: number): Promise<void> {
    await this.db.query(
      "UPDATE quota_products SET quota_amount = $2, updated_at = NOW() WHERE product_id = $1",
      [productId, quotaAmount],
    );
  }
}
