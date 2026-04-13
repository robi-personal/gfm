"use client";

import { useState } from "react";

export default function ContactSection() {
  const [form, setForm] = useState({ name: "", email: "", subject: "", message: "" });
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const isError = status === "error";

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("sending");
    try {
      const res = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error();
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  };

  const inputClass =
    "w-full px-4 py-3 rounded-xl bg-white border border-[#E8E6F0] text-[#1A1A2E] placeholder-[#94A3B8] text-sm focus:outline-none focus:border-[#772FC0] focus:ring-2 focus:ring-[#772FC0]/10 transition-all";

  return (
    <section id="contact" className="bg-[#F7F6FB] py-24 px-4 sm:px-6">
      <div className="max-w-6xl mx-auto">

        {/* Header */}
        <div className="text-center mb-14">
          <span className="inline-block text-xs font-semibold tracking-widest uppercase text-[#772FC0] mb-4">
            CONTACT
          </span>
          <h2 className="text-3xl sm:text-4xl font-bold text-[#1A1A2E] mb-4">
            Have a question? We&apos;d love to hear from you.
          </h2>
          <p className="text-[#64748B] text-lg max-w-xl mx-auto">
            Feature request, feedback, or just a hello — we read every message.
          </p>
        </div>

        <div className="grid lg:grid-cols-5 gap-10 items-start">

          {/* Left info column */}
          <div className="lg:col-span-2 space-y-6">

            <div className="bg-white border border-[#E8E6F0] rounded-2xl p-6 space-y-5">
              {/* Response time */}
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-[#F3F0FA] flex items-center justify-center shrink-0">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#772FC0" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-semibold text-[#1A1A2E]">Quick responses</p>
                  <p className="text-sm text-[#64748B] mt-0.5">We typically reply within 24 hours on business days.</p>
                </div>
              </div>

              {/* Privacy */}
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-[#F3F0FA] flex items-center justify-center shrink-0">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#772FC0" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-semibold text-[#1A1A2E]">Your message is private</p>
                  <p className="text-sm text-[#64748B] mt-0.5">We never share your contact information with anyone.</p>
                </div>
              </div>

              {/* Feedback */}
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-[#F3F0FA] flex items-center justify-center shrink-0">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#772FC0" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-semibold text-[#1A1A2E]">Feedback shapes the app</p>
                  <p className="text-sm text-[#64748B] mt-0.5">Every message helps us prioritise what gets built next.</p>
                </div>
              </div>
            </div>

            {/* Quote card */}
            <div className="bg-[#772FC0] rounded-2xl p-6 text-white">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="white" opacity="0.3" className="mb-3">
                <path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z" />
                <path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z" />
              </svg>
              <p className="text-sm leading-relaxed text-white/90">
                Every piece of feedback helps us build a better product. We take all messages seriously.
              </p>
              <div className="flex items-center gap-3 mt-4">
                <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center text-xs font-bold">G</div>
                <div>
                  <p className="text-xs font-semibold">GFM Team</p>
                  <p className="text-xs text-white/60">gfm.app</p>
                </div>
              </div>
            </div>

          </div>

          {/* Right form */}
          <div className="lg:col-span-3 bg-white border border-[#E8E6F0] rounded-2xl p-8 shadow-sm">
            {status === "sent" ? (
              <div className="flex flex-col items-center justify-center py-12 text-center space-y-4">
                <div className="w-14 h-14 rounded-full bg-[#F3F0FA] flex items-center justify-center">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#772FC0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                </div>
                <h3 className="text-xl font-bold text-[#1A1A2E]">Message sent!</h3>
                <p className="text-[#64748B] text-sm max-w-xs">Thanks for reaching out. We&apos;ll get back to you within 24 hours.</p>
                <button
                  onClick={() => { setStatus("idle"); setForm({ name: "", email: "", subject: "", message: "" }); }}
                  className="mt-2 text-sm text-[#772FC0] hover:text-[#5B1F94] font-medium transition-colors"
                >
                  Send another message
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div className="grid sm:grid-cols-2 gap-5">
                  <div className="space-y-1.5">
                    <label className="text-xs font-semibold text-[#1A1A2E] uppercase tracking-wide">Full Name</label>
                    <input
                      type="text"
                      name="name"
                      required
                      value={form.name}
                      onChange={handleChange}
                      placeholder="Your name"
                      className={inputClass}
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-xs font-semibold text-[#1A1A2E] uppercase tracking-wide">Email Address</label>
                    <input
                      type="email"
                      name="email"
                      required
                      value={form.email}
                      onChange={handleChange}
                      placeholder="you@example.com"
                      className={inputClass}
                    />
                  </div>
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-[#1A1A2E] uppercase tracking-wide">Subject</label>
                  <input
                    type="text"
                    name="subject"
                    required
                    value={form.subject}
                    onChange={handleChange}
                    placeholder="Feature request, bug report, or just hello"
                    className={inputClass}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-[#1A1A2E] uppercase tracking-wide">Message</label>
                  <textarea
                    name="message"
                    required
                    rows={5}
                    value={form.message}
                    onChange={handleChange}
                    placeholder="Tell us what's on your mind..."
                    className={`${inputClass} resize-none`}
                  />
                </div>
                {isError && (
                  <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-3">
                    Something went wrong. Please try again.
                  </p>
                )}
                <button
                  type="submit"
                  disabled={status === "sending"}
                  className="w-full py-3.5 rounded-xl bg-[#772FC0] hover:bg-[#5B1F94] disabled:opacity-60 text-white text-sm font-semibold transition-all duration-200 hover:shadow-lg hover:shadow-[#772FC0]/30 flex items-center justify-center gap-2"
                >
                  {status === "sending" ? (
                    <>
                      <svg className="animate-spin" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M21 12a9 9 0 1 1-6.219-8.56" />
                      </svg>
                      Sending…
                    </>
                  ) : (
                    <>
                      Send Message
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <line x1="22" y1="2" x2="11" y2="13" />
                        <polygon points="22 2 15 22 11 13 2 9 22 2" />
                      </svg>
                    </>
                  )}
                </button>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
