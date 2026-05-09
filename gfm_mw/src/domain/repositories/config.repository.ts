export interface ConfigRepository {
  getAll(): Promise<Record<string, string>>;
  set(key: string, value: string): Promise<void>;
}
