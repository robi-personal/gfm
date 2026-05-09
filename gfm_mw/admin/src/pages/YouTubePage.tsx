import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

export default function YouTubePage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [draft,  setDraft]  = useState<string>("");
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then((cfg) => {
      setConfig(cfg);
      setDraft(String(cfg["YOUTUBE_MONTHLY_MINUTES"] ?? "300"));
    }).catch((e: Error) => setErr(e.message));
  }, []);

  const current = config ? Number(config["YOUTUBE_MONTHLY_MINUTES"] ?? 300) : 300;
  const dirty = config !== null && draft !== String(current);

  async function save() {
    const n = parseInt(draft, 10);
    if (isNaN(n) || n < 0) { setErr("Must be a non-negative integer."); return; }
    setSaving(true);
    setErr("");
    setOk("");
    try {
      const updated = await patchConfig({ YOUTUBE_MONTHLY_MINUTES: n });
      setConfig(updated);
      setDraft(String(updated["YOUTUBE_MONTHLY_MINUTES"]));
      setOk("Saved.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>YouTube Minute Cap</h2>
            <p>Monthly rolling cap per premium user. Set to 0 to disable YouTube processing entirely.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && (
            <div className="field-row">
              <div>
                <div className="field-label">Monthly minutes per user</div>
                <div className="field-hint">Rolling 30-day window. Resets automatically.</div>
              </div>
              <div className="field-control">
                <input
                  type="number"
                  min="0"
                  step="1"
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  style={{ width: 110 }}
                />
                <span style={{ color: "var(--text-secondary)", fontSize: 12 }}>min/month</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {err && <div className="alert alert-error">⚠ {err}</div>}
      {ok  && <div className="alert alert-success">✓ {ok}</div>}

      <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 4 }}>
        <button className="btn-primary" disabled={!dirty || saving} onClick={save}>
          {saving ? "Saving…" : "Save changes"}
        </button>
      </div>
    </>
  );
}
