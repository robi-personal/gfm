import { useState, useEffect } from "react";
import { getWhitelist, addWhitelistEntry, deleteWhitelistEntry, WhitelistEntry } from "../api";

export default function WhitelistPage() {
  const [entries, setEntries] = useState<WhitelistEntry[]>([]);
  const [email, setEmail]     = useState("");
  const [note,  setNote]      = useState("");
  const [err,   setErr]       = useState("");
  const [ok,    setOk]        = useState("");
  const [adding, setAdding]   = useState(false);

  useEffect(() => {
    getWhitelist()
      .then(setEntries)
      .catch((e: Error) => setErr(e.message));
  }, []);

  async function handleAdd() {
    setErr(""); setOk("");
    if (!email.trim()) { setErr("Email is required."); return; }
    setAdding(true);
    try {
      const entry = await addWhitelistEntry(email.trim(), note.trim() || undefined);
      setEntries((prev) => {
        const idx = prev.findIndex((e) => e.email === entry.email);
        return idx >= 0
          ? [entry, ...prev.filter((_, i) => i !== idx)]
          : [entry, ...prev];
      });
      setEmail(""); setNote("");
      setOk(`Added ${entry.email} to whitelist.`);
    } catch (e: unknown) {
      setErr((e as Error).message);
    } finally {
      setAdding(false);
    }
  }

  async function handleDelete(entryEmail: string) {
    if (!confirm(`Remove ${entryEmail} from the whitelist?`)) return;
    setErr(""); setOk("");
    try {
      await deleteWhitelistEntry(entryEmail);
      setEntries((prev) => prev.filter((e) => e.email !== entryEmail));
      setOk(`Removed ${entryEmail}.`);
    } catch (e: unknown) {
      setErr((e as Error).message);
    }
  }

  return (
    <>
      <div className="card">
        <div className="card-header">
          <div>
            <h2>Quota Whitelist</h2>
            <p>Whitelisted users have unlimited generations and bypass all quota checks.</p>
          </div>
        </div>
        <div className="card-body">
          <div style={{ display: "flex", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
            <input
              type="email"
              placeholder="user@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              style={{ flex: "1 1 220px", padding: "6px 10px" }}
              onKeyDown={(e) => e.key === "Enter" && handleAdd()}
            />
            <input
              type="text"
              placeholder="Note (optional)"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              style={{ flex: "2 1 300px", padding: "6px 10px" }}
              onKeyDown={(e) => e.key === "Enter" && handleAdd()}
            />
            <button className="btn-primary" disabled={adding} onClick={handleAdd}>
              {adding ? "Adding…" : "Add"}
            </button>
          </div>

          {!entries.length && !err && <p style={{ color: "var(--text-secondary)" }}>No entries yet.</p>}
          {entries.length > 0 && (
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
              <thead>
                <tr style={{ borderBottom: "1px solid var(--border)" }}>
                  <th style={{ textAlign: "left", padding: "8px 0", fontWeight: 600 }}>Email</th>
                  <th style={{ textAlign: "left", padding: "8px 12px", fontWeight: 600 }}>Note</th>
                  <th style={{ textAlign: "left", padding: "8px 12px", fontWeight: 600 }}>Added By</th>
                  <th style={{ textAlign: "left", padding: "8px 12px", fontWeight: 600 }}>Created At</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {entries.map((e) => (
                  <tr key={e.email} style={{ borderBottom: "1px solid var(--border)" }}>
                    <td style={{ padding: "10px 0", fontWeight: 500 }}>{e.email}</td>
                    <td style={{ padding: "10px 12px", color: "var(--text-secondary)" }}>{e.note ?? "—"}</td>
                    <td style={{ padding: "10px 12px", color: "var(--text-secondary)" }}>{e.addedBy ?? "—"}</td>
                    <td style={{ padding: "10px 12px", color: "var(--text-secondary)", whiteSpace: "nowrap" }}>
                      {new Date(e.createdAt).toLocaleDateString()}
                    </td>
                    <td style={{ padding: "10px 0", textAlign: "right" }}>
                      <button
                        style={{ color: "#ef4444", background: "none", border: "none", cursor: "pointer", fontSize: 13 }}
                        onClick={() => handleDelete(e.email)}
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {err && <div className="alert alert-error" style={{ marginTop: 12 }}>⚠ {err}</div>}
      {ok  && <div className="alert alert-success" style={{ marginTop: 12 }}>✓ {ok}</div>}
    </>
  );
}
