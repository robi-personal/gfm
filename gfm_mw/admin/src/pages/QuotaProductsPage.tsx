import { useState, useEffect, useRef } from "react";
import { getQuotaProducts, patchQuotaProduct, QuotaProduct } from "../api";

const TYPE_BADGE: Record<string, { label: string; color: string }> = {
  subscription: { label: "subscription", color: "#3b82f6" },
  topup:        { label: "top-up",       color: "#22c55e" },
  free:         { label: "free",         color: "#6b7280" },
};

function InlineNumberInput({
  value,
  onCommit,
}: {
  value: number;
  onCommit: (n: number) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft]     = useState(String(value));
  const inputRef = useRef<HTMLInputElement>(null);

  function start() {
    setDraft(String(value));
    setEditing(true);
    setTimeout(() => inputRef.current?.focus(), 0);
  }

  function commit() {
    const n = parseInt(draft, 10);
    if (!isNaN(n) && n >= 0) {
      onCommit(n);
    }
    setEditing(false);
  }

  if (editing) {
    return (
      <input
        ref={inputRef}
        type="number"
        min="0"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => { if (e.key === "Enter") commit(); if (e.key === "Escape") setEditing(false); }}
        style={{ width: 80, padding: "2px 6px" }}
      />
    );
  }
  return (
    <span
      style={{ cursor: "pointer", borderBottom: "1px dashed var(--text-secondary)", paddingBottom: 1 }}
      onClick={start}
      title="Click to edit"
    >
      {value}
    </span>
  );
}

export default function QuotaProductsPage() {
  const [products, setProducts] = useState<QuotaProduct[]>([]);
  const [err, setErr]           = useState("");
  const [ok,  setOk]            = useState("");

  useEffect(() => {
    getQuotaProducts()
      .then(setProducts)
      .catch((e: Error) => setErr(e.message));
  }, []);

  async function handleCommit(productId: string, quotaAmount: number) {
    setErr(""); setOk("");
    try {
      const updated = await patchQuotaProduct(productId, quotaAmount);
      setProducts((prev) => prev.map((p) => p.productId === productId ? updated : p));
      setOk(`Updated ${productId} → ${quotaAmount}`);
    } catch (e: unknown) {
      setErr((e as Error).message);
    }
  }

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Quota Products</h2>
            <p>Click a quota amount to edit it inline. Changes apply immediately.</p>
          </div>
        </div>
        <div className="card-body">
          {!products.length && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {products.length > 0 && (
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
              <thead>
                <tr style={{ borderBottom: "1px solid var(--border)" }}>
                  <th style={{ textAlign: "left", padding: "8px 0", fontWeight: 600 }}>Display Name</th>
                  <th style={{ textAlign: "left", padding: "8px 12px", fontWeight: 600 }}>Type</th>
                  <th style={{ textAlign: "left", padding: "8px 0", fontWeight: 600 }}>Quota Amount</th>
                </tr>
              </thead>
              <tbody>
                {products.map((p) => {
                  const badge = TYPE_BADGE[p.productType] ?? { label: p.productType, color: "#6b7280" };
                  return (
                    <tr key={p.productId} style={{ borderBottom: "1px solid var(--border)" }}>
                      <td style={{ padding: "10px 0" }}>
                        <div style={{ fontWeight: 500 }}>{p.displayName}</div>
                        <div style={{ color: "var(--text-secondary)", fontSize: 12 }}>{p.productId}</div>
                      </td>
                      <td style={{ padding: "10px 12px" }}>
                        <span style={{
                          background: badge.color,
                          color: "#fff",
                          borderRadius: 4,
                          padding: "2px 8px",
                          fontSize: 12,
                          fontWeight: 500,
                        }}>
                          {badge.label}
                        </span>
                      </td>
                      <td style={{ padding: "10px 0" }}>
                        <InlineNumberInput
                          value={p.quotaAmount}
                          onCommit={(n) => handleCommit(p.productId, n)}
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <div className="card" style={{ marginTop: 12 }}>
        <div className="card-body" style={{ padding: "12px 20px" }}>
          <p style={{ margin: 0, color: "var(--text-secondary)", fontSize: 13 }}>
            ⚠ Product IDs must match App Store Connect / RevenueCat product IDs exactly.
          </p>
        </div>
      </div>

      {err && <div className="alert alert-error" style={{ marginTop: 12 }}>⚠ {err}</div>}
      {ok  && <div className="alert alert-success" style={{ marginTop: 12 }}>✓ {ok}</div>}
    </>
  );
}
