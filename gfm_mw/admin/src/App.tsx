import { BrowserRouter, Routes, Route, NavLink, Navigate } from "react-router-dom";
import { hasToken, clearToken } from "./api";
import LoginPage from "./pages/LoginPage";
import KillSwitchesPage from "./pages/KillSwitchesPage";
import BudgetCapsPage from "./pages/BudgetCapsPage";
import RateLimitsPage from "./pages/RateLimitsPage";
import YouTubePage from "./pages/YouTubePage";

const NAV = [
  {
    section: "Operations",
    items: [
      { to: "/admin/kill-switches", icon: "⛔", label: "Kill Switches" },
      { to: "/admin/budget-caps",   icon: "💰", label: "Budget Caps"   },
      { to: "/admin/rate-limits",   icon: "🚦", label: "Rate Limits"   },
      { to: "/admin/youtube",       icon: "▶",  label: "YouTube"       },
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
  "/admin/kill-switches": "Kill Switches",
  "/admin/budget-caps":   "Budget Caps",
  "/admin/rate-limits":   "Rate Limits",
  "/admin/youtube":       "YouTube",
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
            <Route path="/admin/kill-switches" element={<KillSwitchesPage />} />
            <Route path="/admin/budget-caps"   element={<BudgetCapsPage />} />
            <Route path="/admin/rate-limits"   element={<RateLimitsPage />} />
            <Route path="/admin/youtube"       element={<YouTubePage />} />
            <Route path="*"                    element={<Navigate to="/admin/kill-switches" replace />} />
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
