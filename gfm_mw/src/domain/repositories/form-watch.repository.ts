import { FormWatch } from "../entities/form-watch.entity";

export interface FormWatchRepository {
  /** Upsert by (form_id, user_id) — replaces watch_id if user re-toggled. */
  upsert(watch: Omit<FormWatch, "createdAt">): Promise<void>;

  /** Delete by watch_id (the toggle-off path). */
  deleteByWatchId(watchId: string): Promise<void>;

  /** All watches for a given form (Pub/Sub fan-out — usually 1 row). */
  listByFormId(formId: string): Promise<FormWatch[]>;

  /** Check if a Pub/Sub message has already been processed. */
  isMessageProcessed(messageId: string): Promise<boolean>;

  /** Mark a Pub/Sub message as processed. */
  markMessageProcessed(messageId: string): Promise<void>;
}
