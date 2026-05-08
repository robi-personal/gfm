import * as http from "node:http";
import * as https from "node:https";
import { lookup as dnsLookup } from "node:dns/promises";
import { isIP } from "node:net";
import ipaddr from "ipaddr.js";
import sanitizeHtml from "sanitize-html";

// All limits per docs/rate-limiting-abuse.md §6.
const MAX_REDIRECTS = 3;
const MAX_BODY = 5 * 1024 * 1024;            // §6.6 — 5MB raw
const DNS_TIMEOUT_MS = 5_000;                // §6.5
const CONNECT_TIMEOUT_MS = 5_000;            // §6.5
const PER_URL_TIMEOUT_MS = 10_000;           // §6.5
const TOTAL_BUDGET_MS = 25_000;              // §6.5
const CONCURRENCY = 3;                       // §6.8
const TEXT_CHAR_LIMIT = 10_000;              // §6.9 — ≈2500 tokens

const USER_AGENT =
  "GoogleFormsCompanion-AI/1.0 (+https://example.com/bot-info)"; // §6.7

const ALLOWED_CONTENT_TYPES = [
  "text/html",
  "text/plain",
  "application/xhtml+xml",
];

// §6.2 — blocked CIDRs (private, loopback, link-local incl. 169.254.169.254
// cloud metadata, multicast, reserved, IPv6 equivalents).
const BLOCKED_RANGES: string[] = [
  // IPv4
  "0.0.0.0/8",
  "10.0.0.0/8",
  "100.64.0.0/10",
  "127.0.0.0/8",
  "169.254.0.0/16",
  "172.16.0.0/12",
  "192.0.0.0/24",
  "192.0.2.0/24",
  "192.168.0.0/16",
  "198.18.0.0/15",
  "198.51.100.0/24",
  "203.0.113.0/24",
  "224.0.0.0/4",
  "240.0.0.0/4",
  "255.255.255.255/32",
  // IPv6
  "::/128",
  "::1/128",
  "fc00::/7",
  "fe80::/10",
  "ff00::/8",
  "::ffff:0:0/96",
  "64:ff9b::/96",
];

export type FetchErrorReason =
  | "private_ip_resolved"
  | "no_dns_records"
  | "too_many_redirects"
  | "redirect_without_location"
  | "unsupported_content_type"
  | "body_too_large"
  | "fetch_timeout"
  | "fetch_failed";

export class FetchError extends Error {
  readonly reason: FetchErrorReason;
  readonly details: Record<string, unknown>;

  constructor(reason: FetchErrorReason, details: Record<string, unknown> = {}) {
    super(reason);
    this.name = "FetchError";
    this.reason = reason;
    this.details = details;
  }
}

// ── SSRF IP filter ──────────────────────────────────────────────────────────

function isPublicIp(addr: string): boolean {
  let parsed: ipaddr.IPv4 | ipaddr.IPv6;
  try {
    parsed = ipaddr.parse(addr);
  } catch {
    return false;
  }
  for (const range of BLOCKED_RANGES) {
    let cidr: [ipaddr.IPv4 | ipaddr.IPv6, number];
    try {
      cidr = ipaddr.parseCIDR(range);
    } catch {
      continue;
    }
    if (parsed.kind() !== cidr[0].kind()) continue;
    // Type guard: `match` requires the CIDR's address kind to match.
    if (parsed.kind() === "ipv4") {
      if ((parsed as ipaddr.IPv4).match(cidr as [ipaddr.IPv4, number])) return false;
    } else {
      if ((parsed as ipaddr.IPv6).match(cidr as [ipaddr.IPv6, number])) return false;
    }
  }
  return true;
}

interface ResolvedAddress {
  address: string;
  family: 4 | 6;
}

async function resolveAndCheck(hostname: string): Promise<ResolvedAddress> {
  // If the host is already an IP literal, skip DNS but still validate.
  const literalFamily = isIP(hostname);
  if (literalFamily !== 0) {
    if (!isPublicIp(hostname)) {
      throw new FetchError("private_ip_resolved", { ip: hostname, hostname });
    }
    return { address: hostname, family: literalFamily as 4 | 6 };
  }

  let records: { address: string; family: number }[];
  try {
    records = await Promise.race([
      dnsLookup(hostname, { all: true }),
      new Promise<never>((_, reject) =>
        setTimeout(
          () => reject(new FetchError("fetch_timeout", { phase: "dns", hostname })),
          DNS_TIMEOUT_MS,
        ),
      ),
    ]);
  } catch (e) {
    if (e instanceof FetchError) throw e;
    throw new FetchError("no_dns_records", {
      hostname,
      cause: e instanceof Error ? e.message : String(e),
    });
  }

  if (!records || records.length === 0) {
    throw new FetchError("no_dns_records", { hostname });
  }

  // Reject if ANY record is private — defeats one-record-public, rest-private rebinding.
  for (const r of records) {
    if (!isPublicIp(r.address)) {
      throw new FetchError("private_ip_resolved", { ip: r.address, hostname });
    }
  }

  const first = records[0];
  return { address: first.address, family: first.family === 6 ? 6 : 4 };
}

// ── Single HTTP transaction ────────────────────────────────────────────────

interface RawResponse {
  statusCode: number;
  headers: http.IncomingHttpHeaders;
  body: http.IncomingMessage;
}

function fetchOnce(
  urlStr: string,
  pinned: ResolvedAddress,
  signal: AbortSignal,
): Promise<RawResponse> {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const isHttps = u.protocol === "https:";
    const lib = isHttps ? https : http;
    const port = u.port ? Number(u.port) : isHttps ? 443 : 80;

    // Pin DNS to the pre-validated IP. Node calls this in net.connect; signature
    // matches dns.lookup. This is the rebinding defense — the OS resolver is
    // never consulted again after resolveAndCheck().
    const pinnedLookup = (
      _hostname: string,
      options: unknown,
      callback: (
        err: NodeJS.ErrnoException | null,
        address: string | { address: string; family: number }[],
        family?: number,
      ) => void,
    ): void => {
      const all =
        options && typeof options === "object" && "all" in options
          ? Boolean((options as { all?: boolean }).all)
          : false;
      if (all) {
        callback(null, [{ address: pinned.address, family: pinned.family }]);
      } else {
        callback(null, pinned.address, pinned.family);
      }
    };

    const requestOpts: https.RequestOptions = {
      method: "GET",
      protocol: u.protocol,
      hostname: u.hostname,
      port,
      path: (u.pathname || "/") + u.search,
      headers: {
        "User-Agent": USER_AGENT,
        Accept: "text/html, text/plain, application/xhtml+xml",
        Host: u.host,
        Connection: "close",
      },
      lookup: pinnedLookup as https.RequestOptions["lookup"],
    };
    if (isHttps) {
      // SNI must use the original hostname even though we connect to the pinned IP.
      (requestOpts as https.RequestOptions).servername = u.hostname;
    }

    let connectTimer: NodeJS.Timeout | null = null;
    let settled = false;

    const cleanup = (): void => {
      if (connectTimer) {
        clearTimeout(connectTimer);
        connectTimer = null;
      }
      signal.removeEventListener("abort", onAbort);
    };

    const fail = (err: FetchError): void => {
      if (settled) return;
      settled = true;
      cleanup();
      try {
        req.destroy();
      } catch {
        // ignore
      }
      reject(err);
    };

    const onAbort = (): void => {
      fail(new FetchError("fetch_timeout", { phase: "abort", url: urlStr }));
    };

    if (signal.aborted) {
      reject(new FetchError("fetch_timeout", { phase: "abort", url: urlStr }));
      return;
    }
    signal.addEventListener("abort", onAbort, { once: true });

    const req = lib.request(requestOpts, (res) => {
      if (settled) {
        res.resume();
        return;
      }
      settled = true;
      if (connectTimer) {
        clearTimeout(connectTimer);
        connectTimer = null;
      }
      // Keep the abort listener live so callers can still abort body reading.
      resolve({
        statusCode: res.statusCode ?? 0,
        headers: res.headers,
        body: res,
      });
    });

    connectTimer = setTimeout(() => {
      fail(new FetchError("fetch_timeout", { phase: "connect", url: urlStr }));
    }, CONNECT_TIMEOUT_MS);

    req.on("error", (err) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(
        new FetchError("fetch_failed", {
          url: urlStr,
          message: err instanceof Error ? err.message : String(err),
        }),
      );
    });

    req.end();
  });
}

// ── Body reading with streaming cap ─────────────────────────────────────────

async function readBodyCapped(
  stream: http.IncomingMessage,
  signal: AbortSignal,
): Promise<Buffer> {
  const chunks: Buffer[] = [];
  let total = 0;

  const onAbort = (): void => {
    stream.destroy(new FetchError("fetch_timeout", { phase: "body" }));
  };
  if (signal.aborted) {
    stream.destroy();
    throw new FetchError("fetch_timeout", { phase: "body" });
  }
  signal.addEventListener("abort", onAbort, { once: true });

  try {
    for await (const chunk of stream) {
      const buf =
        typeof chunk === "string" ? Buffer.from(chunk, "utf-8") : (chunk as Buffer);
      total += buf.length;
      if (total > MAX_BODY) {
        stream.destroy();
        throw new FetchError("body_too_large", { bytesSeen: total });
      }
      chunks.push(buf);
    }
  } catch (e) {
    if (e instanceof FetchError) throw e;
    if (signal.aborted) {
      throw new FetchError("fetch_timeout", { phase: "body" });
    }
    throw new FetchError("fetch_failed", {
      message: e instanceof Error ? e.message : String(e),
    });
  } finally {
    signal.removeEventListener("abort", onAbort);
  }

  return Buffer.concat(chunks, total);
}

// ── Text extraction ────────────────────────────────────────────────────────

function extractText(buf: Buffer, contentType: string): string {
  const decoded = buf.toString("utf-8");
  let text: string;
  if (contentType.startsWith("text/plain")) {
    text = decoded;
  } else {
    text = sanitizeHtml(decoded, {
      allowedTags: [],
      allowedAttributes: {},
    });
  }
  const collapsed = text.replace(/\s+/g, " ").trim();
  return collapsed.length > TEXT_CHAR_LIMIT
    ? collapsed.slice(0, TEXT_CHAR_LIMIT)
    : collapsed;
}

// ── One-URL pipeline (with redirect handling) ──────────────────────────────

async function fetchOneUrl(
  startUrl: string,
  totalSignal: AbortSignal,
): Promise<string> {
  if (totalSignal.aborted) {
    throw new FetchError("fetch_timeout", { phase: "total", url: startUrl });
  }

  const perUrlController = new AbortController();
  const perUrlTimer = setTimeout(
    () => perUrlController.abort(),
    PER_URL_TIMEOUT_MS,
  );
  const mirrorAbort = (): void => perUrlController.abort();
  totalSignal.addEventListener("abort", mirrorAbort);

  try {
    let current = startUrl;
    let redirects = 0;

    while (true) {
      let parsed: URL;
      try {
        parsed = new URL(current);
      } catch {
        throw new FetchError("fetch_failed", {
          reason: "invalid_url",
          url: current,
        });
      }

      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
        throw new FetchError("fetch_failed", {
          reason: "unsupported_protocol",
          protocol: parsed.protocol,
          url: current,
        });
      }

      // §6.2 + §6.3 — re-resolve and re-check on every hop.
      const resolved = await resolveAndCheck(parsed.hostname);
      const resp = await fetchOnce(current, resolved, perUrlController.signal);

      // Redirect: discard body, recurse with new URL.
      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        resp.body.resume();
        if (++redirects > MAX_REDIRECTS) {
          throw new FetchError("too_many_redirects", { url: startUrl });
        }
        const loc = resp.headers["location"];
        if (!loc || typeof loc !== "string") {
          throw new FetchError("redirect_without_location", { url: current });
        }
        try {
          current = new URL(loc, current).toString();
        } catch {
          throw new FetchError("fetch_failed", {
            reason: "invalid_redirect_target",
            location: loc,
          });
        }
        continue;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        resp.body.resume();
        throw new FetchError("fetch_failed", {
          statusCode: resp.statusCode,
          url: current,
        });
      }

      // §6.4 — content-type allowlist BEFORE reading body.
      const ctRaw = resp.headers["content-type"] ?? "";
      const ct = String(ctRaw).toLowerCase().split(";")[0]!.trim();
      if (!ALLOWED_CONTENT_TYPES.some((p) => ct.startsWith(p))) {
        resp.body.resume();
        throw new FetchError("unsupported_content_type", {
          contentType: ct,
          url: current,
        });
      }

      // §6.6 — streaming cap (never trust Content-Length).
      const buf = await readBodyCapped(resp.body, perUrlController.signal);
      return extractText(buf, ct);
    }
  } catch (e) {
    if (perUrlController.signal.aborted && !(e instanceof FetchError)) {
      throw new FetchError("fetch_timeout", { phase: "per_url", url: startUrl });
    }
    throw e;
  } finally {
    clearTimeout(perUrlTimer);
    totalSignal.removeEventListener("abort", mirrorAbort);
  }
}

// ── Public API ─────────────────────────────────────────────────────────────

export async function fetchUrls(
  urls: string[],
): Promise<{ url: string; text: string }[]> {
  if (urls.length === 0) return [];

  const totalAbort = new AbortController();
  const totalTimer = setTimeout(() => totalAbort.abort(), TOTAL_BUDGET_MS);

  try {
    const results: ({ url: string; text: string } | undefined)[] = new Array(
      urls.length,
    );
    const errors: (FetchError | undefined)[] = new Array(urls.length);

    let nextIdx = 0;
    const worker = async (): Promise<void> => {
      while (true) {
        const i = nextIdx++;
        if (i >= urls.length) return;
        const url = urls[i]!;
        try {
          const text = await fetchOneUrl(url, totalAbort.signal);
          results[i] = { url, text };
        } catch (e) {
          errors[i] =
            e instanceof FetchError
              ? e
              : new FetchError("fetch_failed", {
                  url,
                  message: e instanceof Error ? e.message : String(e),
                });
        }
      }
    };

    const workerCount = Math.min(CONCURRENCY, urls.length);
    await Promise.all(
      Array.from({ length: workerCount }, () => worker()),
    );

    // Per spec: "fetchUrls() should propagate FetchError per-URL." We surface the
    // first failure (with url in details) so the caller in Task 14 can decide
    // partial-vs-total handling. Successful URLs are discarded on any failure
    // rather than returning a half-populated array — mirrors §6.5's "partial
    // results are discarded" rule for timeouts.
    for (const err of errors) {
      if (err) throw err;
    }

    return results.map((r) => r!);
  } finally {
    clearTimeout(totalTimer);
  }
}
