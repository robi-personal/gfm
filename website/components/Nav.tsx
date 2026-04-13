"use client";

import { useState, useEffect } from "react";
import Link from "next/link";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "bg-white/90 backdrop-blur-md border-b border-[#E8E6F0] shadow-sm"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="w-8 h-8 rounded-lg bg-[#772FC0] flex items-center justify-center shadow-lg shadow-[#772FC0]/30 group-hover:bg-[#5B1F94] transition-colors">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="white"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <rect x="4" y="3" width="16" height="18" rx="2" />
                <line x1="8" y1="8" x2="16" y2="8" />
                <line x1="8" y1="12" x2="16" y2="12" />
                <line x1="8" y1="16" x2="13" y2="16" />
              </svg>
            </div>
            <span className="text-lg font-bold text-[#1A1A2E] tracking-tight">GFM</span>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden md:flex items-center gap-8">
            <a
              href="/#features"
              className="text-sm text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            >
              Features
            </a>
            <a
              href="/#how-it-works"
              className="text-sm text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            >
              How it Works
            </a>
            <a
              href="/#contact"
              className="text-sm text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            >
              Contact
            </a>
            <Link
              href="/privacy"
              className="text-sm text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            >
              Privacy
            </Link>
            <Link
              href="/terms"
              className="text-sm text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            >
              Terms
            </Link>
          </nav>

          {/* CTA */}
          <div className="hidden md:flex items-center">
            <a
              href="/#notify"
              className="px-4 py-2 rounded-full bg-[#772FC0] hover:bg-[#5B1F94] text-white text-sm font-medium transition-all duration-200 hover:shadow-lg hover:shadow-[#772FC0]/30"
            >
              Get Early Access
            </a>
          </div>

          {/* Mobile hamburger */}
          <button
            className="md:hidden p-2 text-[#64748B] hover:text-[#1A1A2E] transition-colors"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label="Toggle menu"
          >
            {menuOpen ? (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            ) : (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
            )}
          </button>
        </div>

        {/* Mobile menu */}
        {menuOpen && (
          <div className="md:hidden border-t border-[#E8E6F0] bg-white py-4 space-y-1 animate-fade-in">
            <a
              href="/#features"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2.5 text-sm text-[#64748B] hover:text-[#1A1A2E] hover:bg-[#F3F0FA] rounded-lg transition-colors"
            >
              Features
            </a>
            <a
              href="/#how-it-works"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2.5 text-sm text-[#64748B] hover:text-[#1A1A2E] hover:bg-[#F3F0FA] rounded-lg transition-colors"
            >
              How it Works
            </a>
            <a
              href="/#contact"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2.5 text-sm text-[#64748B] hover:text-[#1A1A2E] hover:bg-[#F3F0FA] rounded-lg transition-colors"
            >
              Contact
            </a>
            <Link
              href="/privacy"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2.5 text-sm text-[#64748B] hover:text-[#1A1A2E] hover:bg-[#F3F0FA] rounded-lg transition-colors"
            >
              Privacy
            </Link>
            <Link
              href="/terms"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2.5 text-sm text-[#64748B] hover:text-[#1A1A2E] hover:bg-[#F3F0FA] rounded-lg transition-colors"
            >
              Terms
            </Link>
            <div className="pt-2 px-3">
              <a
                href="/#notify"
                onClick={() => setMenuOpen(false)}
                className="block w-full text-center px-4 py-2.5 rounded-full bg-[#772FC0] hover:bg-[#5B1F94] text-white text-sm font-medium transition-colors"
              >
                Get Early Access
              </a>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
