"use client";

import { FadeIn } from "../effects/FadeIn";

const quotes = [
  {
    text: "Switched from Paste last week. Same features, half the price. No brainer.",
    author: "David R.",
    role: "iOS Developer",
  },
  {
    text: "The Paste Stack alone is worth it. I fill a stack of 10 items and paste them into forms one by one. Saves me hours.",
    author: "Megan K.",
    role: "Content Strategist",
  },
  {
    text: "Finally a clipboard manager that feels native. Instant, keyboard-driven, no Electron garbage.",
    author: "James L.",
    role: "Backend Engineer",
  },
];

export function SocialProof() {
  return (
    <section className="relative py-20 border-t border-[var(--gray-200)]">
      <div className="mx-auto max-w-[var(--container)] px-10">
        {/* Stats bar */}
        <FadeIn>
          <div className="flex flex-wrap items-center justify-center gap-x-12 gap-y-6 mb-16">
            {[
              { value: "257", label: "early adopters" },
              { value: "4.9", label: "avg rating" },
              { value: "50%", label: "cheaper than Paste" },
              { value: "0.3s", label: "avg launch time" },
            ].map((stat) => (
              <div key={stat.label} className="text-center">
                <p className="text-2xl md:text-3xl font-semibold text-[var(--black)]">
                  {stat.value}
                </p>
                <p className="mt-1 font-mono text-[11px] text-[var(--gray-500)] uppercase tracking-[0.1em]">
                  {stat.label}
                </p>
              </div>
            ))}
          </div>
        </FadeIn>

        {/* Quotes - grid-as-divider pattern */}
        <div
          className="grid gap-px md:grid-cols-3 border border-[var(--gray-200)]"
          style={{ background: "var(--gray-200)" }}
        >
          {quotes.map((quote, i) => (
            <FadeIn key={quote.author} delay={i * 0.08}>
              <div className="bg-[var(--white)] p-6 h-full flex flex-col">
                <p className="text-[14px] text-[var(--gray-600)] leading-relaxed flex-1">
                  &ldquo;{quote.text}&rdquo;
                </p>
                <div className="mt-4 pt-4 border-t border-[var(--gray-200)]">
                  <p className="text-[13px] font-medium text-[var(--black)]">
                    {quote.author}
                  </p>
                  <p className="font-mono text-[11px] text-[var(--gray-400)]">
                    {quote.role}
                  </p>
                </div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
