import { QuotaWhitelistEntry } from "../entities/quota-whitelist-entry";

export interface QuotaWhitelistRepository {
  contains(email: string): Promise<boolean>;
  getAll(): Promise<QuotaWhitelistEntry[]>;
  add(email: string, note: string | null, addedBy: string | null): Promise<QuotaWhitelistEntry>;
  remove(email: string): Promise<void>;
}
