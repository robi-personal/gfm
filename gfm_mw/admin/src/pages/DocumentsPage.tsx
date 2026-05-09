import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

export default function DocumentsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [draft,  setDraft]  = useState<string>("");
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then((cfg) => {
      setConfig(cfg);
      setDraft(String(cfg["PDF_PAGES_PER_QUOTA"] ?? "50"));
    }).catch((e: Error) => setErr(e.message));
  }, []);

  const current = config ? Number(config["PDF_PAGES_PER_QUOTA"] ?? 50) : 50;
  const dirty = config !== null && draft !== String(current);

  async function save() {
    const n = parseInt(draft, 10);
    if (isNaN(n) || n < 1) { setErr("Must be a positive integer."); return; }
    setSaving(true);
    setErr("");
    setOk("");
    try {
      const updated = await patchConfig({ PDF_PAGES_PER_QUOTA: n });
      setConfig(updated);
      setDraft(String(updated["PDF_PAGES_PER_QUOTA"]));
      setOk("Saved.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const examplePages = [50, 100, 200, 300];
  const pagesPerQuota = parseInt(draft, 10) || 50;

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>PDF / Book Quota Cost</h2>
            <p>Large documents are billed as multiple quota units based on page count.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && (
            <div className="field-row">
              <div>
                <div className="field-label">Pages per quota unit</div>
                <div className="field-hint">Each block of this many pages costs 1 quota. Partial blocks round up.</div>
              </div>
              <div className="field-control">
                <input
                  type="number"
                  min="1"
                  step="1"
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  style={{ width: 110 }}
                />
                <span style={{ color: "var(--text-secondary)", fontSize: 12 }}>pages / quota</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {config && (
        <div className="card" style={{ marginTop: 16 }}>
          <div className="card-header">
            <div>
              <h2>Cost Reference</h2>
              <p>Quota deducted for common document sizes at current setting.</p>
            </div>
          </div>
          <div className="card-body">
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
              <thead>
                <tr style={{ color: "var(--text-secondary)", textAlign: "left" }}>
                  <th style={{ padding: "6px 12px", borderBottom: "1px solid var(--border)" }}>Pages</th>
                  <th style={{ padding: "6px 12px", borderBottom: "1px solid var(--border)" }}>Quota cost</th>
                </tr>
              </thead>
              <tbody>
                {examplePages.map((p) => (
                  <tr key={p}>
                    <td style={{ padding: "8px 12px", color: "var(--text-primary)" }}>{p} pages</td>
                    <td style={{ padding: "8px 12px" }}>
                      <span className="badge badge-info">
                        {Math.ceil(p / pagesPerQuota)} quota
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

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
