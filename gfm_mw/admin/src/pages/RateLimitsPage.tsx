import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

const FIELDS = [
  { key: "RL_AI_GLOBAL_HOURLY", label: "AI global",         hint: "Total AI requests / hour across all users",   unit: "req/hr" },
  { key: "RL_AI_IP_HOURLY",     label: "AI per IP",          hint: "AI requests / hour per IP address",           unit: "req/hr" },
  { key: "RL_AI_USER_HOURLY",   label: "AI per user / hour", hint: "AI requests / hour per authenticated user",   unit: "req/hr" },
  { key: "RL_AI_USER_DAILY",    label: "AI per user / day",  hint: "AI requests / day per authenticated user",    unit: "req/day" },
  { key: "RL_RC_IP_MIN",        label: "RevenueCat webhook", hint: "Webhook POST requests / minute per IP",       unit: "req/min" },
];

export default function RateLimitsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then(setConfig).catch((e: Error) => setErr(e.message));
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
      const n = parseInt(drafts[key], 10);
      if (isNaN(n) || n < 1) {
        setErr(`${key} must be a positive integer.`);
        setSaving(false);
        return;
      }
      updates[key] = n;
    }
    try {
      const updated = await patchConfig(updates);
      setConfig(updated);
      setDrafts({});
      setOk("Rate limits saved. New values are active immediately.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const dirty = Object.keys(drafts).length > 0;

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Rate Limits</h2>
            <p>Changes apply instantly without a server restart.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && FIELDS.map(({ key, label, hint, unit }) => (
            <div className="field-row" key={key}>
              <div>
                <div className="field-label">{label}</div>
                <div className="field-hint">{hint}</div>
              </div>
              <div className="field-control">
                <input
                  type="number"
                  min="1"
                  step="1"
                  value={getDraft(key)}
                  onChange={(e) => setDraft(key, e.target.value)}
                  style={{ width: 100 }}
                />
                <span style={{ color: "var(--text-secondary)", fontSize: 12, whiteSpace: "nowrap" }}>
                  {unit}
                </span>
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
