"use client";

import { FadeIn } from "../effects/FadeIn";

export function Download() {
  return (
    <section id="download" className="relative py-32 pb-40">
      {/* Background glow */}
      <div
        className="pointer-events-none absolute bottom-0 left-1/2 -translate-x-1/2 h-[500px] w-[800px] rounded-full opacity-[0.07]"
        style={{
          background:
            "radial-gradient(circle, var(--cyan) 0%, transparent 60%)",
        }}
        aria-hidden
      />

      <div className="relative z-10 mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-cyan-400/70 mb-4">
              Get started
            </p>
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-extrabold tracking-tight">
              Stop paying $30/yr for
              <br />
              <span className="gradient-text">your clipboard</span>
            </h2>
            <p className="mt-5 text-lg text-white/40 max-w-md mx-auto">
              257 people already switched. Join them while it&apos;s still free.
            </p>

            {/* Download Button */}
            <div className="mt-10">
              <a
                href="#"
                className="group relative inline-flex h-16 items-center gap-3 rounded-2xl px-12 text-[17px] font-bold text-white transition-all duration-300 hover:brightness-110 hover:scale-[1.02] glow-btn"
                style={{ background: "var(--gradient-primary)" }}
              >
                <svg
                  className="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                  />
                </svg>
                Download Free for macOS
              </a>
            </div>

            {/* Trust signals */}
            <div className="mt-5 flex flex-wrap items-center justify-center gap-x-5 gap-y-1 text-[12px] text-white/25">
              <span className="flex items-center gap-1.5">
                <svg className="h-3 w-3 text-emerald-400/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                No account needed
              </span>
              <span className="flex items-center gap-1.5">
                <svg className="h-3 w-3 text-emerald-400/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                No credit card
              </span>
              <span className="flex items-center gap-1.5">
                <svg className="h-3 w-3 text-emerald-400/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                30-second setup
              </span>
              <span className="flex items-center gap-1.5">
                <svg className="h-3 w-3 text-emerald-400/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                macOS 12+
              </span>
            </div>

            {/* Quick Start Steps */}
            <div className="mt-20 grid gap-4 sm:grid-cols-3 max-w-[640px] mx-auto text-left">
              {[
                {
                  step: "1",
                  title: "Download & install",
                  description: "Open the .dmg and drag Superclip to Applications",
                },
                {
                  step: "2",
                  title: "Grant permissions",
                  description: "Allow Accessibility access when prompted",
                },
                {
                  step: "3",
                  title: "Press ⌘⇧A",
                  description: "Open Superclip from anywhere. That's it.",
                },
              ].map((item) => (
                <div key={item.step} className="glass p-5">
                  <span className="mb-3 flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-cyan-500/20 to-purple-500/20 text-[13px] font-bold text-cyan-400">
                    {item.step}
                  </span>
                  <p className="text-[13px] font-semibold text-white/80 mb-1">
                    {item.title}
                  </p>
                  <p className="text-[12px] leading-relaxed text-white/35">
                    {item.description}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
