const features = [
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="5" r="1" fill="currentColor" stroke="none" />
        <path d="M8 9h8M8 13h6" />
        <rect x="3" y="3" width="18" height="18" rx="3" />
      </svg>
    ),
    title: "All Question Types",
    description:
      "Short answer, multiple choice, checkboxes, scales, date, time, ratings, grids — every type the Forms API supports.",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10" />
        <polyline points="12 8 12 12 15 15" />
        <path d="M9.5 3.5l1.5 2M14.5 3.5l-1.5 2" />
      </svg>
    ),
    title: "Quiz Mode & Answer Keys",
    description:
      "Set point values, correct answers, and per-question feedback. Grade with confidence.",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
      </svg>
    ),
    title: "View & Export Responses",
    description:
      "Summary charts, individual drill-down, and one-tap CSV export via the system share sheet.",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
        <path d="M3 6l2 6-2 6" />
      </svg>
    ),
    title: "Sections & Branching",
    description:
      "Page breaks with conditional logic. Route respondents to different sections based on their answers.",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <circle cx="8.5" cy="8.5" r="1.5" />
        <polyline points="21 15 16 10 5 21" />
      </svg>
    ),
    title: "Images & YouTube",
    description:
      "Embed photos from your gallery or YouTube videos directly in your form, no web UI required.",
  },
  {
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="18" cy="5" r="3" />
        <circle cx="6" cy="12" r="3" />
        <circle cx="18" cy="19" r="3" />
        <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
        <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
      </svg>
    ),
    title: "Share in One Tap",
    description:
      "Copy the responder link or share via any app. Forms are real Google Forms from the moment you create them.",
  },
];

export default function Features() {
  return (
    <section id="features" className="py-28 px-4 sm:px-6 bg-[#F7F6FB]">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-16">
          <span className="text-xs font-semibold tracking-widest text-[#772FC0] uppercase">
            Capabilities
          </span>
          <h2 className="mt-3 text-4xl sm:text-5xl font-bold text-[#1A1A2E] leading-tight">
            Everything you need to manage{" "}
            <br className="hidden sm:block" />
            forms on the go.
          </h2>
        </div>

        {/* Feature grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="bg-white border border-[#E8E6F0] rounded-2xl p-6 transition-all duration-200 hover:-translate-y-1 hover:border-[#772FC0]/40 hover:shadow-md"
            >
              <div className="w-10 h-10 rounded-xl bg-[#F3F0FA] flex items-center justify-center text-[#772FC0] mb-5">
                {feature.icon}
              </div>
              <h3 className="text-lg font-semibold text-[#1A1A2E] mb-2">
                {feature.title}
              </h3>
              <p className="text-sm text-[#64748B] leading-relaxed">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
