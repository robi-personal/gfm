"use client";

import { useState } from "react";

function AndroidBadge() {
  return (
    <div className="flex items-center gap-3 px-5 py-3 rounded-xl bg-[#F3F0FA] border border-[#E8E6F0] cursor-not-allowed opacity-50 select-none">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" className="text-[#64748B]">
        <path d="M17.523 15.3414C17.523 15.9135 17.057 16.3795 16.485 16.3795H7.515C6.943 16.3795 6.477 15.9135 6.477 15.3414V8.9805H17.523V15.3414ZM15.0045 3.8985L16.2495 1.512C16.3215 1.3725 16.2645 1.2 16.125 1.128C15.9855 1.056 15.813 1.113 15.741 1.2525L14.481 3.6675C13.6995 3.333 12.867 3.1395 12 3.1395C11.133 3.1395 10.3005 3.333 9.519 3.6675L8.259 1.2525C8.187 1.113 8.0145 1.056 7.875 1.128C7.7355 1.2 7.6785 1.3725 7.7505 1.512L8.9955 3.8985C7.344 4.7715 6.1725 6.3765 6 8.298H18C17.8275 6.3765 16.656 4.7715 15.0045 3.8985ZM9.75 6.75C9.3375 6.75 9 6.4125 9 6C9 5.5875 9.3375 5.25 9.75 5.25C10.1625 5.25 10.5 5.5875 10.5 6C10.5 6.4125 10.1625 6.75 9.75 6.75ZM14.25 6.75C13.8375 6.75 13.5 6.4125 13.5 6C13.5 5.5875 13.8375 5.25 14.25 5.25C14.6625 5.25 15 5.5875 15 6C15 6.4125 14.6625 6.75 14.25 6.75Z" />
      </svg>
      <div className="text-left">
        <div className="text-[10px] text-[#64748B] leading-none mb-0.5">Coming Soon</div>
        <div className="text-sm font-semibold text-[#64748B] leading-none">Google Play</div>
      </div>
    </div>
  );
}

function AppleBadge() {
  return (
    <div className="flex items-center gap-3 px-5 py-3 rounded-xl bg-[#F3F0FA] border border-[#E8E6F0] cursor-not-allowed opacity-50 select-none">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" className="text-[#64748B]">
        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
      </svg>
      <div className="text-left">
        <div className="text-[10px] text-[#64748B] leading-none mb-0.5">Coming Soon</div>
        <div className="text-sm font-semibold text-[#64748B] leading-none">App Store</div>
      </div>
    </div>
  );
}

export default function CtaSection() {
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;
    setLoading(true);
    try {
      const res = await fetch("/api/notify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (!res.ok) throw new Error();
      setSubmitted(true);
    } catch {
      // still show success to user
      setSubmitted(true);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section id="notify" className="py-28 px-4 sm:px-6 bg-[#F7F6FB]">
      <div className="max-w-3xl mx-auto text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#F3F0FA] border border-[#E8E6F0] mb-8">
          <span className="w-1.5 h-1.5 rounded-full bg-[#772FC0]" />
          <span className="text-xs font-medium text-[#772FC0] tracking-wide">
            Coming to Android &amp; iOS
          </span>
        </div>

        <h2 className="text-4xl sm:text-5xl font-bold text-[#1A1A2E] mb-5 leading-tight">
          Ready to manage Google Forms{" "}
          <span className="gradient-text">from anywhere?</span>
        </h2>
        <p className="text-lg text-[#64748B] mb-12">
          Be the first to know when GFM launches. One email. No spam.
        </p>

        {/* Store badges */}
        <div className="flex flex-wrap items-center justify-center gap-4 mb-12">
          <AndroidBadge />
          <AppleBadge />
        </div>

        {/* Divider */}
        <div className="flex items-center gap-4 mb-10">
          <div className="flex-1 h-px bg-[#E8E6F0]" />
          <span className="text-xs text-[#94A3B8] font-medium">or get notified</span>
          <div className="flex-1 h-px bg-[#E8E6F0]" />
        </div>

        {/* Email form */}
        {submitted ? (
          <div className="bg-white border border-[#E8E6F0] rounded-2xl px-8 py-8 animate-fade-in">
            <div className="w-12 h-12 rounded-full bg-[#F3F0FA] flex items-center justify-center mx-auto mb-4">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#772FC0" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </div>
            <p className="text-lg font-semibold text-[#1A1A2E] mb-1">You&apos;re on the list!</p>
            <p className="text-[#64748B] text-sm mb-6">We&apos;ll send one email when GFM is ready to download.</p>
            <a
              href="https://github.com/robi-personal/gfm/releases/download/v1.0.0-beta/app-release.apk"
              className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-[#772FC0] hover:bg-[#5B1F94] text-white text-sm font-medium transition-all duration-200 hover:shadow-lg hover:shadow-[#772FC0]/30"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <polyline points="7 10 12 15 17 10" />
                <line x1="12" y1="15" x2="12" y2="3" />
              </svg>
              Download Beta APK
            </a>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="max-w-md mx-auto">
            <div className="flex gap-2 mb-3">
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                className="flex-1 bg-white border border-[#E8E6F0] text-[#1A1A2E] placeholder:text-[#94A3B8] rounded-xl px-4 py-3 text-sm outline-none focus:border-[#772FC0] focus:ring-1 focus:ring-[#772FC0]/30 transition-all"
              />
              <button
                type="submit"
                disabled={loading}
                className="px-5 py-3 rounded-xl bg-[#772FC0] hover:bg-[#5B1F94] disabled:opacity-60 text-white text-sm font-medium transition-all duration-200 hover:shadow-lg hover:shadow-[#772FC0]/30 whitespace-nowrap"
              >
                {loading ? (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="animate-spin">
                    <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
                  </svg>
                ) : (
                  "Notify Me"
                )}
              </button>
            </div>
            <p className="text-xs text-[#94A3B8]">
              You will be listed as a tester.
            </p>
          </form>
        )}
      </div>
    </section>
  );
}
