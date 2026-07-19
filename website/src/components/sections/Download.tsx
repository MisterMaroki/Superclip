"use client";

import { FadeIn } from "../effects/FadeIn";
import { KeyboardKey } from "../ui/KeyboardKey";

export function Download() {
  return (
    <section id="download" className="relative py-32 pb-40">
      <div className="relative z-10 mx-auto max-w-[var(--container)] px-10">
        <FadeIn>
          <div className="text-center">
            <p className="section-label mb-4">Get started</p>
            <h2 style={{ fontSize: "clamp(32px, 5vw, 48px)" }}>
              Stop paying $30/yr for your clipboard
            </h2>
            <p className="mt-5 text-[17px] text-[var(--gray-500)] max-w-md mx-auto">
              257 people already switched. Join them while it&apos;s still free.
            </p>

            {/* Download Button */}
            <div className="mt-10">
              <a
                href="/Superclip.dmg"
                download
                className="inline-flex h-16 items-center gap-3 border border-[var(--black)] bg-[var(--black)] px-12 text-[17px] font-medium tracking-[0.025em] text-[var(--white)] transition-colors duration-150 hover:bg-[var(--gray-800)]"
              >
                <svg
                  className="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
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
            <div className="mt-5 flex flex-wrap items-center justify-center gap-x-5 gap-y-1 text-[12px] text-[var(--gray-400)]">
              {[
                "No account needed",
                "No credit card",
                "30-second setup",
                "macOS 14+",
              ].map((text) => (
                <span key={text} className="flex items-center gap-1.5">
                  <svg
                    className="h-3 w-3 text-[var(--black)]"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M4.5 12.75l6 6 9-13.5"
                    />
                  </svg>
                  {text}
                </span>
              ))}
            </div>

            {/* Quick Start Steps */}
            <div
              className="mt-20 grid gap-px sm:grid-cols-3 max-w-[640px] mx-auto text-left border border-[var(--gray-200)]"
              style={{ background: "var(--gray-200)" }}
            >
              {[
                {
                  step: "1",
                  title: "Download & install",
                  description:
                    "Open the .dmg and drag Superclip to Applications",
                },
                {
                  step: "2",
                  title: "Grant permissions",
                  description: "Allow Accessibility access when prompted",
                },
                {
                  step: "3",
                  title: "Press \u2318\u21E7A",
                  description: "Open Superclip from anywhere. That's it.",
                },
              ].map((item) => (
                <div key={item.step} className="bg-[var(--white)] p-5">
                  <span className="mb-3 flex h-8 w-8 items-center justify-center border border-[var(--gray-200)] font-mono text-[13px] font-bold text-[var(--black)]">
                    {item.step}
                  </span>
                  <p className="text-[13px] font-medium text-[var(--black)] mb-1">
                    {item.title}
                  </p>
                  <p className="text-[12px] leading-relaxed text-[var(--gray-400)]">
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
