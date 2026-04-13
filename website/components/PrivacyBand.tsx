import Link from "next/link";

const pillars = [
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2" y="3" width="20" height="14" rx="2" />
        <path d="M8 21h8M12 17v4" />
        <line x1="2" y1="3" x2="22" y2="3" />
      </svg>
    ),
    title: "No Backend",
    description:
      "GFM has no servers. Every API call goes directly from your phone to Google.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        <polyline points="9 12 11 14 15 10" />
      </svg>
    ),
    title: "Minimal Permissions",
    description:
      "GFM only sees Drive files it created. It cannot read your broader Drive.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <line x1="23" y1="11" x2="17" y2="11" />
      </svg>
    ),
    title: "No Content Logging",
    description:
      "Form content, questions, and response data are never sent to analytics or crash services.",
  },
];

export default function PrivacyBand() {
  return (
    <section
      id="privacy"
      className="relative py-28 px-4 sm:px-6 overflow-hidden"
      style={{
        background:
          "linear-gradient(135deg, #772FC0 0%, #5B1F94 100%)",
      }}
    >
      {/* Decorative blobs */}
      <div className="absolute top-0 left-0 w-72 h-72 bg-white/5 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-white/5 rounded-full blur-3xl pointer-events-none" />

      <div className="relative max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-16">
          <span className="text-xs font-semibold tracking-widest text-white/70 uppercase">
            Privacy-First
          </span>
          <h2 className="mt-3 text-4xl sm:text-5xl font-bold text-white">
            Your data never leaves Google.
          </h2>
          <p className="mt-5 text-white/75 max-w-xl mx-auto text-lg">
            We built GFM without a backend on purpose. There&apos;s no server to breach,
            no database to leak.
          </p>
        </div>

        {/* Pillars */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {pillars.map((pillar) => (
            <div
              key={pillar.title}
              className="glass-hover rounded-2xl p-8 border border-white/20 bg-white/10 backdrop-blur-sm"
            >
              <div className="w-12 h-12 rounded-xl bg-white/15 flex items-center justify-center text-white mb-6">
                {pillar.icon}
              </div>
              <h3 className="text-xl font-semibold text-white mb-3">
                {pillar.title}
              </h3>
              <p className="text-white/75 leading-relaxed">{pillar.description}</p>
            </div>
          ))}
        </div>

        {/* CTA line */}
        <p className="text-center text-white/75">
          Questions about data handling?{" "}
          <Link
            href="/privacy"
            className="text-white underline underline-offset-4 hover:text-white/90 transition-colors font-medium"
          >
            Read our Privacy Policy.
          </Link>
        </p>
      </div>
    </section>
  );
}
