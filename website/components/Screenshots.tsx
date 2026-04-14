"use client";

import { useState, useRef, useEffect } from "react";
import Image from "next/image";

const screenshots = [
  { src: "/screenshots/1.png", alt: "Sign In" },
  { src: "/screenshots/2.png", alt: "Dashboard" },
  { src: "/screenshots/3.png", alt: "Editor" },
  { src: "/screenshots/4.png", alt: "Question Types" },
  { src: "/screenshots/5.png", alt: "Responses" },
  { src: "/screenshots/6.png", alt: "Settings" },
];

export default function Screenshots() {
  const [active, setActive] = useState(0);
  const itemRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    itemRefs.current[active]?.scrollIntoView({
      behavior: "smooth",
      block: "nearest",
      inline: "center",
    });
  }, [active]);

  const prev = () => setActive((i) => Math.max(0, i - 1));
  const next = () => setActive((i) => Math.min(screenshots.length - 1, i + 1));

  return (
    <section className="py-24 bg-white">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="text-xs font-semibold tracking-widest text-[#772FC0] uppercase">
            Screenshots
          </span>
          <h2 className="mt-3 text-3xl sm:text-4xl font-bold tracking-tight text-[#1A1A2E]">
            Simple &amp;{" "}
            <span className="gradient-text">Beautiful Interface</span>
          </h2>
          <p className="mt-4 text-[#64748B] text-lg leading-relaxed">
            Manage your Google Forms on the go — clean, fast, and intuitive.
          </p>
        </div>

        {/* Carousel */}
        <div className="flex items-center justify-center gap-4 sm:gap-6">
          {/* Prev button */}
          <button
            onClick={prev}
            disabled={active === 0}
            aria-label="Previous screenshot"
            className="w-10 h-10 rounded-full border border-[#E8E6F0] bg-white flex items-center justify-center text-[#64748B] hover:border-[#772FC0] hover:text-[#772FC0] transition-all disabled:opacity-20 disabled:cursor-not-allowed shrink-0 shadow-sm"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>

          {/* Screenshot strip */}
          <div className="flex gap-4 sm:gap-6 items-center overflow-x-auto no-scrollbar snap-x snap-mandatory pb-2">
            {screenshots.map((ss, i) => {
              const isActive = i === active;
              return (
                <div
                  key={i}
                  ref={(el) => { itemRefs.current[i] = el; }}
                  onClick={() => setActive(i)}
                  className={`relative flex-shrink-0 cursor-pointer select-none transition-all duration-500 snap-center ${
                    isActive
                      ? "scale-100 opacity-100 z-10"
                      : "scale-90 opacity-40 hover:opacity-60 hover:scale-[0.93]"
                  }`}
                  style={
                    isActive
                      ? { filter: "drop-shadow(0 12px 40px rgba(119,47,192,0.25))" }
                      : undefined
                  }
                >
                  {/* Phone frame */}
                  <div
                    className="w-48 flex flex-col bg-black rounded-[32px] border-2 border-slate-400/80 overflow-hidden"
                    style={{ height: 400 }}
                  >
                    {/* Status bar */}
                    <div className="h-7 shrink-0 bg-black flex items-center justify-between px-4 relative">
                      <div className="absolute top-1.5 left-1/2 -translate-x-1/2 w-14 h-[14px] bg-black rounded-full z-10 border border-slate-800" />
                      <span className="text-[8px] text-slate-400 font-medium">9:41</span>
                      <div className="flex items-center gap-1.5">
                        <div className="flex items-end gap-px">
                          {[4, 6, 8, 10].map((h, j) => (
                            <div key={j} style={{ height: h }} className="w-[2px] bg-slate-500 rounded-sm" />
                          ))}
                        </div>
                        <div className="flex items-center">
                          <div className="w-4 h-[9px] border border-slate-500/60 rounded-[2px] relative">
                            <div className="absolute inset-[2px] right-[3px] bg-[#772FC0]/70 rounded-[1px]" />
                          </div>
                          <div className="w-[2px] h-[5px] bg-slate-500/60 rounded-r-sm ml-px" />
                        </div>
                      </div>
                    </div>

                    {/* Screen content */}
                    <div className="flex-1 relative overflow-hidden">
                      <Image
                        src={ss.src}
                        alt={ss.alt}
                        fill
                        className="object-cover object-top"
                        sizes="192px"
                      />
                    </div>

                    {/* Home bar */}
                    <div className="h-5 shrink-0 flex items-center justify-center bg-black">
                      <div className="w-10 h-[3px] bg-slate-700 rounded-full" />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Next button */}
          <button
            onClick={next}
            disabled={active === screenshots.length - 1}
            aria-label="Next screenshot"
            className="w-10 h-10 rounded-full border border-[#E8E6F0] bg-white flex items-center justify-center text-[#64748B] hover:border-[#772FC0] hover:text-[#772FC0] transition-all disabled:opacity-20 disabled:cursor-not-allowed shrink-0 shadow-sm"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        {/* Dot indicators */}
        <div className="flex justify-center gap-2 mt-8">
          {screenshots.map((_, i) => (
            <button
              key={i}
              onClick={() => setActive(i)}
              className={`rounded-full transition-all duration-300 ${
                i === active
                  ? "w-6 h-2 bg-[#772FC0]"
                  : "w-2 h-2 bg-[#E8E6F0] hover:bg-[#772FC0]/40"
              }`}
              aria-label={`Go to screenshot ${i + 1}`}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
