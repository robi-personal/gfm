import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

const DEFAULTS = {
  NOTIFICATION_TITLE_TEMPLATE: "New form response",
  NOTIFICATION_BODY_TEMPLATE:  "You have a new response in {formTitle}",
};

const SAMPLE_FORM_TITLE = "Customer Feedback Survey";

export default function NotificationsPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [titleDraft, setTitleDraft] = useState<string>("");
  const [bodyDraft,  setBodyDraft]  = useState<string>("");
  const [err,    setErr]    = useState("");
  const [ok,     setOk]     = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then((cfg) => {
      setConfig(cfg);
      setTitleDraft(String(cfg["NOTIFICATION_TITLE_TEMPLATE"] ?? DEFAULTS.NOTIFICATION_TITLE_TEMPLATE));
      setBodyDraft(String(cfg["NOTIFICATION_BODY_TEMPLATE"] ?? DEFAULTS.NOTIFICATION_BODY_TEMPLATE));
    }).catch((e: Error) => setErr(e.message));
  }, []);

  const currentTitle = config ? String(config["NOTIFICATION_TITLE_TEMPLATE"] ?? DEFAULTS.NOTIFICATION_TITLE_TEMPLATE) : DEFAULTS.NOTIFICATION_TITLE_TEMPLATE;
  const currentBody  = config ? String(config["NOTIFICATION_BODY_TEMPLATE"]  ?? DEFAULTS.NOTIFICATION_BODY_TEMPLATE)  : DEFAULTS.NOTIFICATION_BODY_TEMPLATE;
  const dirty = config !== null && (titleDraft !== currentTitle || bodyDraft !== currentBody);

  async function save() {
    if (titleDraft.trim().length === 0 || bodyDraft.trim().length === 0) {
      setErr("Title and body cannot be empty.");
      return;
    }
    setSaving(true);
    setErr("");
    setOk("");
    try {
      const updated = await patchConfig({
        NOTIFICATION_TITLE_TEMPLATE: titleDraft,
        NOTIFICATION_BODY_TEMPLATE:  bodyDraft,
      });
      setConfig(updated);
      setTitleDraft(String(updated["NOTIFICATION_TITLE_TEMPLATE"]));
      setBodyDraft(String(updated["NOTIFICATION_BODY_TEMPLATE"]));
      setOk("Saved.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const fill = (s: string) => s.split("{formTitle}").join(SAMPLE_FORM_TITLE);
  const titlePreview = fill(titleDraft);
  const bodyPreview  = fill(bodyDraft);

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Response notification</h2>
            <p>Push notification text shown to users when their form receives a new response.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}
          {config && (
            <>
              <div className="field-row" style={{ flexDirection: "column", alignItems: "stretch", gap: 8 }}>
                <div>
                  <div className="field-label">Title template</div>
                  <div className="field-hint">Supported placeholder: <code>{"{formTitle}"}</code></div>
                </div>
                <input
                  type="text"
                  value={titleDraft}
                  onChange={(e) => setTitleDraft(e.target.value)}
                  style={{ width: "100%" }}
                />
              </div>

              <div className="field-row" style={{ flexDirection: "column", alignItems: "stretch", gap: 8, marginTop: 16 }}>
                <div>
                  <div className="field-label">Body template</div>
                  <div className="field-hint">Supported placeholder: <code>{"{formTitle}"}</code></div>
                </div>
                <input
                  type="text"
                  value={bodyDraft}
                  onChange={(e) => setBodyDraft(e.target.value)}
                  style={{ width: "100%" }}
                />
              </div>

              <div
                style={{
                  marginTop: 20,
                  padding: 14,
                  background: "var(--bg-secondary, #f5f5f7)",
                  borderRadius: 12,
                  border: "1px solid var(--border, #e5e5ea)",
                }}
              >
                <div style={{ fontSize: 11, color: "var(--text-secondary)", letterSpacing: 0.5, marginBottom: 6 }}>
                  PREVIEW
                </div>
                <div style={{ fontWeight: 600, color: "var(--text-primary)" }}>{titlePreview}</div>
                <div style={{ color: "var(--text-secondary)", marginTop: 2 }}>{bodyPreview}</div>
              </div>
            </>
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
