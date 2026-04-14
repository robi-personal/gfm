import Link from "next/link";
import Image from "next/image";

export default function Footer() {
  const currentYear = 2026;

  return (
    <footer className="bg-[#1A1A2E] border-t border-white/10">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-14">
        {/* Main grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-10 pb-10 border-b border-white/10">
          {/* Col 1 — Logo + tagline */}
          <div>
            <div className="flex items-center gap-2.5 mb-4">
              <Image src="/app_logo.svg" alt="GFM logo" width={28} height={28} className="rounded-lg" />
              <span className="text-base font-bold text-white">GFM</span>
            </div>
            <p className="text-sm text-[#94A3B8] leading-relaxed max-w-xs">
              Your forms. Your data. Your phone.
            </p>
            <p className="mt-3 text-xs text-[#94A3B8]/70">
              A privacy-first Google Forms companion for educators and teams.
            </p>
          </div>

          {/* Col 2 — Product links */}
          <div>
            <h4 className="text-xs font-semibold tracking-widest text-[#94A3B8] uppercase mb-5">
              Product
            </h4>
            <ul className="space-y-3">
              <li>
                <a
                  href="/#features"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  Features
                </a>
              </li>
              <li>
                <a
                  href="/#how-it-works"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  How it Works
                </a>
              </li>
              <li>
                <a
                  href="/#privacy"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  Privacy Overview
                </a>
              </li>
              <li>
                <a
                  href="/#notify"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  Get Early Access
                </a>
              </li>
            </ul>
          </div>

          {/* Col 3 — Legal links */}
          <div>
            <h4 className="text-xs font-semibold tracking-widest text-[#94A3B8] uppercase mb-5">
              Legal
            </h4>
            <ul className="space-y-3">
              <li>
                <Link
                  href="/privacy"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link
                  href="/terms"
                  className="text-sm text-[#94A3B8] hover:text-white transition-colors"
                >
                  Terms of Service
                </Link>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-sm text-[#94A3B8]/60">
            &copy; {currentYear} GFM. All rights reserved.
          </p>
          <div className="flex items-center gap-1 text-sm text-[#94A3B8]/60">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-[#9B5CE8]">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span>Privacy-first by design</span>
          </div>
          <Link
            href="/privacy"
            className="text-sm text-[#94A3B8]/60 hover:text-[#9B5CE8] transition-colors"
          >
            Privacy Policy
          </Link>
        </div>
      </div>
    </footer>
  );
}
