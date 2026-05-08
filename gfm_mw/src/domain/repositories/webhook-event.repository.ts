export interface WebhookEventRepository {
  existsById(eventId: string): Promise<boolean>;
  // The insert + user update happen together in a transaction managed by the
  // use case. This method inserts the row; it is called inside that transaction.
  insertIfAbsent(
    eventId: string,
    eventType: string,
    userId: number | null,
    rawPayload: unknown,
  ): Promise<{ inserted: boolean }>;
}
