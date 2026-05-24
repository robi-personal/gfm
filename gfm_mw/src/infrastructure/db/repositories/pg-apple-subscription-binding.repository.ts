import { AppleSubscriptionBindingRepository } from "../../../domain/repositories/apple-subscription-binding.repository";
import { DbClient } from "../postgres";

export class PgAppleSubscriptionBindingRepository implements AppleSubscriptionBindingRepository {
  constructor(private readonly db: DbClient) {}

  async findByTransactionId(originalTransactionId: string): Promise<number | null> {
    const { rows } = await this.db.query<{ user_id: number }>(
      "SELECT user_id FROM apple_subscription_bindings WHERE original_transaction_id = $1",
      [originalTransactionId],
    );
    return rows[0]?.user_id ?? null;
  }

  async bindIfAbsent(originalTransactionId: string, userId: number): Promise<number> {
    await this.db.query(
      `INSERT INTO apple_subscription_bindings (original_transaction_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (original_transaction_id) DO NOTHING`,
      [originalTransactionId, userId],
    );
    const { rows } = await this.db.query<{ user_id: number }>(
      "SELECT user_id FROM apple_subscription_bindings WHERE original_transaction_id = $1",
      [originalTransactionId],
    );
    return rows[0].user_id;
  }
}
