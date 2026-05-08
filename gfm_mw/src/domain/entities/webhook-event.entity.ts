export interface WebhookEvent {
  eventId: string;
  eventType: string;
  userId: number | null;
  rawPayload: unknown;
  processedAt: Date;
}
