import { useState, useEffect } from "react";
import { getConfig, getSpend, patchConfig, Config, SpendData } from "../api";

const GLOBAL_CAPS = [
  { key: "MAX_DAILY_GEMINI_SPEND_USD",   label: "Daily cap",   hint: "Rolling 24 h global limit",  spendKey: "daily"   as const },
  { key: "MAX_WEEKLY_GEMINI_SPEND_USD",  label: "Weekly cap",  hint: "Rolling 7 day global limit",  spendKey: "weekly"  as const },
  { key: "MAX_MONTHLY_GEMINI_SPEND_USD", label: "Monthly cap", hint: "Rolling 30 day global limit", spendKey: "monthly" as const },
];

const USER_CAPS = [
  { key: "MAX_USER_DAILY_GEMINI_USD",   label: "Daily cap",   hint: "Per-user rolling 24 h"  },
  { key: "MAX_USER_WEEKLY_GEMINI_USD",  label: "Weekly cap",  hint: "Per-user rolling 7 days" },
  { key: "MAX_USER_MONTHLY_GEMINI_USD", label: "Monthly cap", hint: "Per-user rolling 30 days" },
];

function pct(spend: number, cap: number) {
  return cap > 0 ? Math.min(100, (spend / cap) * 100) : 0;
}

function barClass(p: number) {
  if (p >= 90) return "danger";
  if (p >= 70) return "warn";
  return "";
}

function spendBadgeClass(p: number) {
  if (p >= 90) return "badge-red";
  if (p >= 70) return "badge-yellow";
  return "badge-green";
}

export default function BudgetCapsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [spend,  setSpend]  = useState<SpendData | null>(null);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    Promise.all([getConfig(), getSpend()])
      .then(([cfg, sp]) => { setConfig(cfg); setSpend(sp); })
      .catch((e: Error) => setErr(e.message));
  }, []);

  function setDraft(key: string, val: string) {
    setDrafts((d) => ({ ...d, [key]: val }));
  }

  function getDraft(key: string): string {
    return key in drafts ? drafts[key] : String(config?.[key] ?? "");
  }

  async function save() {
    setSaving(true);
    setErr("");
    setOk("");
    const updates: Record<string, number> = {};
    for (const key of Object.keys(drafts)) {
      const n = parseFloat(drafts[key]);
      if (isNaN(n) || n < 0) {
        setErr(`Invalid value for ${key}`);
        setSaving(false);
        return;
      }
      updates[key] = n;
    }
    try {
      const updated = await patchConfig(updates);
      setConfig(updated);
      setDrafts({});
      setOk("Caps saved successfully.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const dirty = Object.keys(drafts).length > 0;

  return (
    <>
      {/* Spend tiles */}
      {spend && config && (
        <div className="stat-grid">
          {GLOBAL_CAPS.map(({ label, spendKey, key }) => {
            const cap = Number(config[key] ?? 0);
            const p   = pct(spend[spendKey], cap);
            return (
              <div className="stat-tile" key={key}>
                <div className="stat-label">Global {label}</div>
                <div className="stat-value">${cap.toFixed(2)} <span style={{ fontSize: 13, fontWeight: 400, color: "var(--text-secondary)" }}>cap</span></div>
                <div className="stat-cap">Spent: ${spend[spendKey].toFixed(4)}</div>
                <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 8 }}>
                  <div className="spend-bar-wrap">
                    <div className={`spend-bar-fill ${barClass(p)}`} style={{ width: `${p}%` }} />
                  </div>
                  <span className={`badge ${spendBadgeClass(p)}`}>{p.toFixed(1)}% used</span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Global caps */}
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Global Spend Caps</h2>
            <p>Applies across all users. AI generation is blocked when any cap is reached.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && GLOBAL_CAPS.map(({ key, label, hint }) => (
            <div className="field-row" key={key}>
              <div>
                <div className="field-label">{label}</div>
                <div className="field-hint">{hint}</div>
              </div>
              <div className="field-control">
                <span style={{ color: "var(--text-secondary)", fontSize: 13 }}>$</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={getDraft(key)}
                  onChange={(e) => setDraft(key, e.target.value)}
                  style={{ width: 110 }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Per-user caps */}
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Per-User Spend Caps</h2>
            <p>Individual user limits. Checked on every generation request.</p>
          </div>
        </div>
        <div className="card-body">
          {config && USER_CAPS.map(({ key, label, hint }) => (
            <div className="field-row" key={key}>
              <div>
                <div className="field-label">{label}</div>
                <div className="field-hint">{hint}</div>
              </div>
              <div className="field-control">
                <span style={{ color: "var(--text-secondary)", fontSize: 13 }}>$</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={getDraft(key)}
                  onChange={(e) => setDraft(key, e.target.value)}
                  style={{ width: 110 }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      {err && <div className="alert alert-error">⚠ {err}</div>}
      {ok  && <div className="alert alert-success">✓ {ok}</div>}

      <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 4 }}>
        <button
          className="btn-primary"
          disabled={!dirty || saving}
          onClick={save}
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
      </div>
    </>
  );
}
