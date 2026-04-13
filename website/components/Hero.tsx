export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center overflow-hidden pt-16 bg-[#F7F6FB]">
      {/* Background subtle glow effects */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-[#772FC0]/6 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-[#9B5CE8]/5 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-[#772FC0]/4 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-6xl mx-auto px-4 sm:px-6 py-24 w-full">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Left column */}
          <div className="animate-fade-in-up">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#F3F0FA] border border-[#E8E6F0] mb-8">
              <span className="w-1.5 h-1.5 rounded-full bg-[#772FC0] animate-pulse" />
              <span className="text-xs font-medium text-[#772FC0] tracking-wide">
                For Educators &amp; Teams
              </span>
            </div>

            {/* Headline */}
            <h1 className="text-5xl sm:text-6xl font-bold leading-tight tracking-tight text-[#1A1A2E] mb-6">
              Google Forms,{" "}
              <span className="gradient-text">
                built for your phone.
              </span>
            </h1>

            {/* Subtext */}
            <p className="text-lg text-[#64748B] leading-relaxed mb-10 max-w-md">
              Create, edit, and manage Google Forms from anywhere. Native speed,
              full functionality — no compromises.
            </p>

            {/* CTAs */}
            <div className="flex flex-wrap gap-4 mb-10">
              <a
                href="#notify"
                className="px-6 py-3 rounded-full bg-[#772FC0] hover:bg-[#5B1F94] text-white font-medium transition-all duration-200 hover:shadow-lg hover:shadow-[#772FC0]/30 hover:-translate-y-0.5"
              >
                Get Early Access
              </a>
              <a
                href="#features"
                className="px-6 py-3 rounded-full border border-[#772FC0] hover:border-[#5B1F94] text-[#772FC0] hover:text-[#5B1F94] font-medium transition-all duration-200 hover:-translate-y-0.5"
              >
                See Features
              </a>
            </div>

            {/* Trust line */}
            <div className="flex items-center gap-2 text-sm text-[#94A3B8]">
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="text-[#772FC0] flex-shrink-0"
              >
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
              <span>Your data stays in Google Drive. Always.</span>
            </div>
          </div>

          {/* Right column — Phone mockup */}
          <div className="flex items-center justify-center lg:justify-end animate-fade-in">
            <div className="relative">
              {/* Glow behind phone */}
              <div className="absolute inset-0 bg-[#772FC0]/10 blur-3xl rounded-full scale-75" />

              {/* Phone shell */}
              <svg
                width="280"
                height="560"
                viewBox="0 0 280 560"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
                className="relative drop-shadow-2xl"
              >
                {/* Phone body */}
                <rect
                  x="2"
                  y="2"
                  width="276"
                  height="556"
                  rx="38"
                  fill="#FFFFFF"
                  stroke="#E8E6F0"
                  strokeWidth="1.5"
                />

                {/* Screen area */}
                <rect x="12" y="12" width="256" height="536" rx="30" fill="#F3F0FA" />

                {/* Notch / dynamic island */}
                <rect x="105" y="20" width="70" height="22" rx="11" fill="#FFFFFF" />

                {/* Status bar */}
                <text x="28" y="58" fill="#94A3B8" fontSize="10" fontFamily="system-ui">9:41</text>
                <text x="218" y="58" fill="#94A3B8" fontSize="10" fontFamily="system-ui" textAnchor="middle">●●●</text>

                {/* App bar */}
                <rect x="12" y="65" width="256" height="48" fill="#FFFFFF" />
                <text x="30" y="95" fill="#1A1A2E" fontSize="14" fontWeight="bold" fontFamily="system-ui">My Forms</text>

                {/* Search bar */}
                <rect x="24" y="122" width="232" height="32" rx="10" fill="#FFFFFF" stroke="#E8E6F0" strokeWidth="1" />
                <text x="44" y="142" fill="#94A3B8" fontSize="11" fontFamily="system-ui">Search forms...</text>
                <circle cx="36" cy="138" r="6" stroke="#94A3B8" strokeWidth="1.2" fill="none" />

                {/* Section label */}
                <text x="24" y="176" fill="#772FC0" fontSize="9" fontWeight="600" fontFamily="system-ui" letterSpacing="1">RECENT</text>

                {/* Form card 1 */}
                <rect x="24" y="186" width="232" height="70" rx="12" fill="#FFFFFF" stroke="rgba(119,47,192,0.25)" strokeWidth="1" />
                <rect x="40" y="200" width="28" height="28" rx="8" fill="rgba(119,47,192,0.12)" />
                <text x="46" y="219" fill="#772FC0" fontSize="14" fontFamily="system-ui">✦</text>
                <text x="78" y="211" fill="#1A1A2E" fontSize="11" fontWeight="600" fontFamily="system-ui">End of Year Survey</text>
                <text x="78" y="226" fill="#64748B" fontSize="9.5" fontFamily="system-ui">48 responses · Quiz</text>
                <rect x="40" y="237" width="180" height="7" rx="3.5" fill="#E8E6F0" />
                <rect x="40" y="237" width="110" height="7" rx="3.5" fill="rgba(119,47,192,0.5)" />

                {/* Form card 2 */}
                <rect x="24" y="268" width="232" height="70" rx="12" fill="#FFFFFF" stroke="#E8E6F0" strokeWidth="1" />
                <rect x="40" y="282" width="28" height="28" rx="8" fill="rgba(119,47,192,0.08)" />
                <text x="46" y="301" fill="#772FC0" fontSize="14" fontFamily="system-ui">≡</text>
                <text x="78" y="293" fill="#1A1A2E" fontSize="11" fontWeight="600" fontFamily="system-ui">Math Quiz — Unit 4</text>
                <text x="78" y="308" fill="#64748B" fontSize="9.5" fontFamily="system-ui">23 responses · Active</text>
                <rect x="40" y="319" width="180" height="7" rx="3.5" fill="#E8E6F0" />
                <rect x="40" y="319" width="60" height="7" rx="3.5" fill="rgba(119,47,192,0.4)" />

                {/* Form card 3 */}
                <rect x="24" y="350" width="232" height="70" rx="12" fill="#FFFFFF" stroke="#E8E6F0" strokeWidth="1" />
                <rect x="40" y="364" width="28" height="28" rx="8" fill="rgba(16,185,129,0.12)" />
                <text x="46" y="383" fill="#059669" fontSize="14" fontFamily="system-ui">✓</text>
                <text x="78" y="375" fill="#1A1A2E" fontSize="11" fontWeight="600" fontFamily="system-ui">Field Trip Permission</text>
                <text x="78" y="390" fill="#64748B" fontSize="9.5" fontFamily="system-ui">7 responses · Draft</text>
                <rect x="40" y="401" width="180" height="7" rx="3.5" fill="#E8E6F0" />
                <rect x="40" y="401" width="30" height="7" rx="3.5" fill="rgba(16,185,129,0.4)" />

                {/* Bottom nav */}
                <rect x="12" y="500" width="256" height="48" rx="0" fill="#FFFFFF" />
                <rect x="12" y="499" width="256" height="1" fill="#E8E6F0" />

                {/* Bottom nav icons */}
                <rect x="52" y="516" width="16" height="16" rx="2" stroke="#772FC0" strokeWidth="1.5" fill="none" />
                <line x1="55" y1="522" x2="65" y2="522" stroke="#772FC0" strokeWidth="1.2" />
                <line x1="55" y1="526" x2="62" y2="526" stroke="#772FC0" strokeWidth="1.2" />

                <rect x="132" y="516" width="16" height="16" rx="8" stroke="#94A3B8" strokeWidth="1.5" fill="none" />
                <line x1="140" y1="512" x2="140" y2="520" stroke="#94A3B8" strokeWidth="1.2" />

                <circle cx="212" cy="524" r="8" stroke="#94A3B8" strokeWidth="1.5" fill="none" />
                <circle cx="212" cy="524" r="3" fill="#94A3B8" />

                {/* FAB */}
                <circle cx="140" cy="476" r="22" fill="#772FC0" />
                <line x1="140" y1="466" x2="140" y2="486" stroke="white" strokeWidth="2.5" strokeLinecap="round" />
                <line x1="130" y1="476" x2="150" y2="476" stroke="white" strokeWidth="2.5" strokeLinecap="round" />

                {/* Side buttons */}
                <rect x="276" y="140" width="4" height="50" rx="2" fill="#E8E6F0" />
                <rect x="0" y="130" width="4" height="35" rx="2" fill="#E8E6F0" />
                <rect x="0" y="178" width="4" height="35" rx="2" fill="#E8E6F0" />
              </svg>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
