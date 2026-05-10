import { BrowserRouter, Routes, Route, NavLink, Navigate } from "react-router-dom";
import { hasToken, clearToken } from "./api";
import LoginPage from "./pages/LoginPage";
import KillSwitchesPage from "./pages/KillSwitchesPage";
import RateLimitsPage from "./pages/RateLimitsPage";
import YouTubePage from "./pages/YouTubePage";
import DocumentsPage from "./pages/DocumentsPage";
import QuotaProductsPage from "./pages/QuotaProductsPage";
import WhitelistPage from "./pages/WhitelistPage";

const NAV = [
  {
    section: "Operations",
    items: [
      { to: "/admin/kill-switches",   icon: "⛔", label: "Kill Switches"   },
      { to: "/admin/rate-limits",     icon: "🚦", label: "Rate Limits"     },
      { to: "/admin/youtube",         icon: "▶",  label: "YouTube"         },
      { to: "/admin/documents",       icon: "📄", label: "Documents"       },
      { to: "/admin/quota-products",  icon: "🎟", label: "Quota Products"  },
      { to: "/admin/whitelist",       icon: "✅", label: "Whitelist"       },
    ],
  },
];

function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="logo">
          <div className="logo-icon">G</div>
          <div>
            <div className="logo-text">GFM Admin</div>
            <div className="logo-sub">Control Panel</div>
          </div>
        </div>
      </div>

      <nav className="sidebar-nav">
        {NAV.map(({ section, items }) => (
          <div key={section}>
            <div className="nav-section-label">{section}</div>
            {items.map(({ to, icon, label }) => (
              <NavLink
                key={to}
                to={to}
                className={({ isActive }) => `nav-item${isActive ? " active" : ""}`}
              >
                <span className="nav-icon">{icon}</span>
                {label}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button onClick={() => { clearToken(); location.reload(); }}>
          <span>⬅</span> Sign out
        </button>
      </div>
    </aside>
  );
}

const PAGE_TITLES: Record<string, string> = {
  "/admin/kill-switches":  "Kill Switches",
  "/admin/rate-limits":    "Rate Limits",
  "/admin/youtube":        "YouTube",
  "/admin/documents":      "Documents",
  "/admin/quota-products": "Quota Products",
  "/admin/whitelist":      "Whitelist",
};

function Layout() {
  const path = location.pathname;
  const title = PAGE_TITLES[path] ?? "Admin";

  return (
    <div className="layout">
      <Sidebar />
      <div className="main">
        <header className="topbar">
          <span className="topbar-title">{title}</span>
          <span className="topbar-meta">GFM · {new Date().toLocaleDateString()}</span>
        </header>
        <div className="page-content">
          <Routes>
            <Route path="/admin/kill-switches"  element={<KillSwitchesPage />} />
            <Route path="/admin/rate-limits"    element={<RateLimitsPage />} />
            <Route path="/admin/youtube"        element={<YouTubePage />} />
            <Route path="/admin/documents"      element={<DocumentsPage />} />
            <Route path="/admin/quota-products" element={<QuotaProductsPage />} />
            <Route path="/admin/whitelist"      element={<WhitelistPage />} />
            <Route path="*"                     element={<Navigate to="/admin/kill-switches" replace />} />
          </Routes>
        </div>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="*" element={hasToken() ? <Layout /> : <LoginPage />} />
      </Routes>
    </BrowserRouter>
  );
}
