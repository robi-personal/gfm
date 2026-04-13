const steps = [
  {
    number: "01",
    title: "Sign in with Google",
    description:
      "Your existing Google account. GFM requests only the permissions it needs — nothing more.",
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
        <circle cx="12" cy="7" r="4" />
      </svg>
    ),
  },
  {
    number: "02",
    title: "Create or open a form",
    description:
      "Tap + to name a new form, or open any existing one. Forms live in your Google Drive.",
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
        <polyline points="14 2 14 8 20 8" />
        <line x1="12" y1="13" x2="12" y2="17" />
        <line x1="10" y1="15" x2="14" y2="15" />
      </svg>
    ),
  },
  {
    number: "03",
    title: "Build, share, and review",
    description:
      "Add questions, enable quiz mode, hit share. Responses appear in the app the moment they arrive.",
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
      </svg>
    ),
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="py-28 px-4 sm:px-6 bg-white">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-20">
          <span className="text-xs font-semibold tracking-widest text-[#772FC0] uppercase">
            Workflow
          </span>
          <h2 className="mt-3 text-4xl sm:text-5xl font-bold text-[#1A1A2E] leading-tight">
            From zero to published form{" "}
            <span className="gradient-text">in under 45 seconds.</span>
          </h2>
        </div>

        {/* Steps */}
        <div className="relative">
          {/* Connecting line — desktop */}
          <div className="absolute left-[2.375rem] top-16 bottom-16 w-px bg-[#E8E6F0] hidden md:block" />

          <div className="space-y-8">
            {steps.map((step) => (
              <div
                key={step.number}
                className="relative flex gap-6 md:gap-8 group"
              >
                {/* Number badge */}
                <div className="flex-shrink-0 relative z-10">
                  <div className="w-[4.75rem] h-[4.75rem] rounded-2xl bg-[#772FC0] flex flex-col items-center justify-center transition-all duration-300 group-hover:bg-[#5B1F94] group-hover:shadow-lg group-hover:shadow-[#772FC0]/25">
                    <span className="text-[10px] font-bold text-white/80 tracking-widest">
                      {step.number}
                    </span>
                    <div className="mt-1 text-white">{step.icon}</div>
                  </div>
                </div>

                {/* Content */}
                <div className="flex-1 bg-white border border-[#E8E6F0] rounded-2xl px-6 py-5 group-hover:border-[#772FC0]/30 group-hover:shadow-sm transition-all duration-300">
                  <h3 className="text-xl font-semibold text-[#1A1A2E] mb-2">
                    {step.title}
                  </h3>
                  <p className="text-[#64748B] leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
