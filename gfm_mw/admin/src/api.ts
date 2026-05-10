const BASE = "/admin";

function getToken(): string {
  return sessionStorage.getItem("adminToken") ?? "";
}

export function setToken(t: string): void {
  sessionStorage.setItem("adminToken", t);
}

export function clearToken(): void {
  sessionStorage.removeItem("adminToken");
}

export function hasToken(): boolean {
  return Boolean(sessionStorage.getItem("adminToken"));
}

async function request<T>(path: string, opts?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...opts,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getToken()}`,
      ...opts?.headers,
    },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<T>;
}

export type Config = Record<string, number | boolean>;
export interface SpendData { daily: number; weekly: number; monthly: number }

export async function login(email: string, password: string): Promise<void> {
  const res = await fetch(`${BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
  }
  const { token } = await res.json() as { token: string };
  setToken(token);
}

export async function getConfig(): Promise<Config> {
  const data = await request<{ config: Config }>("/config");
  return data.config;
}

export async function patchConfig(updates: Partial<Config>): Promise<Config> {
  const data = await request<{ config: Config }>("/config", {
    method: "PATCH",
    body: JSON.stringify(updates),
  });
  return data.config;
}

export async function getSpend(): Promise<SpendData> {
  const data = await request<{ spend: SpendData }>("/spend");
  return data.spend;
}

// ── Quota products ────────────────────────────────────────────────────────────

export interface QuotaProduct {
  productId: string;
  productType: "subscription" | "topup" | "free";
  displayName: string;
  quotaAmount: number;
  updatedAt: string;
}

export async function getQuotaProducts(): Promise<QuotaProduct[]> {
  const data = await request<{ products: QuotaProduct[] }>("/quota-products");
  return data.products;
}

export async function patchQuotaProduct(productId: string, quotaAmount: number): Promise<QuotaProduct> {
  const data = await request<{ product: QuotaProduct }>(`/quota-products/${encodeURIComponent(productId)}`, {
    method: "PATCH",
    body: JSON.stringify({ quotaAmount }),
  });
  return data.product;
}

// ── Whitelist ─────────────────────────────────────────────────────────────────

export interface WhitelistEntry {
  email: string;
  note: string | null;
  addedBy: string | null;
  createdAt: string;
}

export async function getWhitelist(): Promise<WhitelistEntry[]> {
  const data = await request<{ entries: WhitelistEntry[] }>("/whitelist");
  return data.entries;
}

export async function addWhitelistEntry(email: string, note?: string): Promise<WhitelistEntry> {
  const data = await request<{ entry: WhitelistEntry }>("/whitelist", {
    method: "POST",
    body: JSON.stringify({ email, note }),
  });
  return data.entry;
}

export async function deleteWhitelistEntry(email: string): Promise<void> {
  await request(`/whitelist/${encodeURIComponent(email)}`, { method: "DELETE" });
}
