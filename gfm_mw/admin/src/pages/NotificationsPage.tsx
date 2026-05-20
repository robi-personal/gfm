import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

const DEFAULT_TEMPLATE = "You have a new response in {formTitle}";

export default function NotificationsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [draft,  setDraft]  = useState<string>("");
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then((cfg) => {
      setConfig(cfg);
      setDraft(String(cfg["NOTIFICATION_BODY_TEMPLATE"] ?? DEFAULT_TEMPLATE));
    }).catch((e: Error) => setErr(e.message));
  }, []);

  const current = config ? String(config["NOTIFICATION_BODY_TEMPLATE"] ?? DEFAULT_TEMPLATE) : DEFAULT_TEMPLATE;
  const dirty = config !== null && draft !== current;

  async function save() {
    if (draft.trim().length === 0) { setErr("Template cannot be empty."); return; }
    setSaving(true);
    setErr("");
    setOk("");
    try {
      const updated = await patchConfig({ NOTIFICATION_BODY_TEMPLATE: draft });
      setConfig(updated);
      setDraft(String(updated["NOTIFICATION_BODY_TEMPLATE"]));
      setOk("Saved.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const preview = draft.split("{formTitle}").join("Customer Feedback Survey");

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Response notification body</h2>
            <p>Push notification text shown to users when their form receives a new response.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && (
            <div className="field-row" style={{ flexDirection: "column", alignItems: "stretch", gap: 8 }}>
              <div>
                <div className="field-label">Body template</div>
                <div className="field-hint">Supported placeholder: <code>{"{formTitle}"}</code></div>
              </div>
              <input
                type="text"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                style={{ width: "100%" }}
              />
              <div style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 4 }}>
                Preview: <strong style={{ color: "var(--text-primary)" }}>{preview}</strong>
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
