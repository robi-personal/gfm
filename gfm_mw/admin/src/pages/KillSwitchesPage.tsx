import { useState, useEffect } from "react";
import { getConfig, patchConfig, Config } from "../api";

export default function KillSwitchesPage() {
  const [config, setConfig] = useState<Config | null>(null);
  const [err, setErr]       = useState("");
  const [ok, setOk]         = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getConfig().then(setConfig).catch((e: Error) => setErr(e.message));
  }, []);

  async function toggle(key: string, current: boolean) {
    setSaving(true);
    setErr("");
    setOk("");
    try {
      const updated = await patchConfig({ [key]: !current });
      setConfig(updated);
      setOk("Change saved successfully.");
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const disabled = Boolean(config?.["AI_GENERATION_DISABLED"]);

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Service Kill Switches</h2>
            <p>Instantly disable features across all users. Changes take effect immediately.</p>
          </div>
        </div>
        <div className="card-body">
          {!config && !err && <p style={{ color: "var(--text-secondary)" }}>Loading…</p>}

          {config && (
            <div className="field-row">
              <div>
                <div className="field-label">AI Generation</div>
                <div className="field-hint">
                  Disables all /ai/generate requests. Use during incidents or cost overruns.
                </div>
              </div>
              <div className="field-control">
                <span className={`badge ${disabled ? "badge-red" : "badge-green"}`}>
                  {disabled ? "● Disabled" : "● Enabled"}
                </span>
                <label className="toggle">
                  <input
                    type="checkbox"
                    checked={disabled}
                    disabled={saving}
                    onChange={() => toggle("AI_GENERATION_DISABLED", disabled)}
                  />
                  <span className="slider" />
                </label>
              </div>
            </div>
          )}

          {err && <div className="alert alert-error">⚠ {err}</div>}
          {ok  && <div className="alert alert-success">✓ {ok}</div>}
        </div>
      </div>
    </>
  );
}
