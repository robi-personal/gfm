const stats = [
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10" />
        <path d="M8 12h8M12 8v8" />
      </svg>
    ),
    value: "10+",
    label: "Question Types",
    description: "Every type the Forms API supports",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="9 11 12 14 22 4" />
        <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" />
      </svg>
    ),
    value: "All",
    label: "Google Forms Features",
    description: "Full parity with the web interface",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      </svg>
    ),
    value: "Zero",
    label: "Backend",
    description: "Your phone talks directly to Google",
  },
];

export default function StatsBar() {
  return (
    <section className="bg-white border-y border-[#E8E6F0]">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-0 divide-y sm:divide-y-0 sm:divide-x divide-[#E8E6F0]">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className="flex items-start gap-4 px-8 py-6 sm:py-0 first:pl-0 last:pr-0"
            >
              <div className="mt-0.5 flex-shrink-0 text-[#772FC0]">{stat.icon}</div>
              <div>
                <div className="flex items-baseline gap-2">
                  <span className="text-2xl font-bold text-[#772FC0]">{stat.value}</span>
                  <span className="text-base font-semibold text-[#1A1A2E]">{stat.label}</span>
                </div>
                <p className="mt-1 text-sm text-[#64748B]">{stat.description}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
