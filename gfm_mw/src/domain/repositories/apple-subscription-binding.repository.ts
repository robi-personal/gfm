export interface AppleSubscriptionBindingRepository {
  /** Returns the userId that owns this transaction, or null if not bound. */
  findByTransactionId(originalTransactionId: string): Promise<number | null>;

  /**
   * Atomically inserts the binding if absent. Returns the userId that owns
   * the binding after the operation — either the passed userId (newly bound)
   * or a pre-existing userId (conflict — caller should reject the operation).
   */
  bindIfAbsent(originalTransactionId: string, userId: number): Promise<number>;
}
