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
    <section className="relative py-20 border-t border-b border-white/[0.04]">
      <div className="mx-auto max-w-[var(--container)] px-6">
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
                <p className="text-2xl md:text-3xl font-extrabold gradient-text">
                  {stat.value}
                </p>
                <p className="mt-1 text-[12px] text-white/30 uppercase tracking-wider font-medium">
                  {stat.label}
                </p>
              </div>
            ))}
          </div>
        </FadeIn>

        {/* Quotes */}
        <div className="grid gap-4 md:grid-cols-3">
          {quotes.map((quote, i) => (
            <FadeIn key={quote.author} delay={i * 0.1}>
              <div className="glass glass-hover p-6 h-full flex flex-col">
                {/* Stars */}
                <div className="flex gap-0.5 mb-4">
                  {Array.from({ length: 5 }).map((_, j) => (
                    <svg
                      key={j}
                      className="h-3.5 w-3.5 text-amber-400"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  ))}
                </div>
                <p className="text-[14px] text-white/60 leading-relaxed flex-1">
                  &ldquo;{quote.text}&rdquo;
                </p>
                <div className="mt-4 pt-4 border-t border-white/[0.06]">
                  <p className="text-[13px] font-semibold text-white/70">
                    {quote.author}
                  </p>
                  <p className="text-[11px] text-white/30">{quote.role}</p>
                </div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
