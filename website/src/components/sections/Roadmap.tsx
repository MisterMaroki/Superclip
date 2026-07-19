"use client";

import { FadeIn } from "../effects/FadeIn";

const milestones = [
  {
    date: "February 2026",
    status: "current" as const,
    title: "macOS Launch",
    description:
      "Full-featured clipboard manager for macOS. Free for the first 1,000 users.",
    features: [
      "Clipboard history & pinboards",
      "Paste Stack & OCR",
      "Keyboard-first navigation",
      "Privacy controls",
    ],
  },
  {
    date: "Late February 2026",
    status: "upcoming" as const,
    title: "Screen Capture Suite",
    description:
      "Built-in screen capture and annotation tools rivaling CleanShot X. No extra subscription needed.",
    features: [
      "Screenshot & screen recording",
      "Annotation & markup tools",
      "Scrolling capture",
      "Quick share & copy",
    ],
  },
  {
    date: "March 2026",
    status: "upcoming" as const,
    title: "iOS Companion App",
    description:
      "Seamless clipboard sync between Mac and iPhone. Full Paste feature parity at half the price.",
    features: [
      "Cross-device clipboard sync",
      "Universal clipboard history",
      "Pinboards on mobile",
      "iCloud-backed storage",
    ],
  },
  {
    date: "April 2026+",
    status: "future" as const,
    title: "Community Decides",
    description:
      "You tell us what to build next. Submit and vote on features below.",
    features: [
      "Vote on features below",
      "Community-driven roadmap",
      "Monthly public updates",
      "Open feedback loop",
    ],
  },
];

const statusLabels = {
  current: "Now",
  upcoming: "Next",
  future: "Soon",
};

export function Roadmap() {
  return (
    <section id="roadmap" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-10">
        <FadeIn>
          <div className="text-center mb-20">
            <p className="section-label mb-4">Roadmap</p>
            <h2 style={{ fontSize: "clamp(32px, 5vw, 48px)" }}>
              Where we&apos;re headed
            </h2>
            <p className="mt-4 text-[17px] text-[var(--gray-500)] max-w-lg mx-auto">
              Superclip is growing fast. Here&apos;s what&apos;s coming &mdash;
              and after that, you decide.
            </p>
          </div>
        </FadeIn>

        <div className="relative max-w-[680px] mx-auto">
          {/* Timeline line */}
          <div className="absolute left-[19px] md:left-1/2 md:-translate-x-px top-0 bottom-0 w-px bg-[var(--gray-200)]" />

          {milestones.map((milestone, i) => {
            const isEven = i % 2 === 0;

            return (
              <FadeIn key={milestone.title} delay={i * 0.08}>
                <div
                  className={`relative flex items-start gap-6 mb-12 last:mb-0
                    md:gap-0 ${isEven ? "md:flex-row" : "md:flex-row-reverse"}
                  `}
                >
                  {/* Dot */}
                  <div className="absolute left-[15px] md:left-1/2 md:-translate-x-1/2 top-1 z-10">
                    <div
                      className={`h-[10px] w-[10px] ${
                        milestone.status === "current"
                          ? "bg-[var(--black)]"
                          : "border border-[var(--gray-300)] bg-[var(--white)]"
                      }`}
                    />
                  </div>

                  {/* Card */}
                  <div className="ml-10 md:ml-0 md:w-[calc(50%-32px)] border border-[var(--gray-200)] p-6">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="inline-flex h-5 items-center border border-[var(--gray-700)] px-2 font-mono text-[10px] uppercase tracking-[0.1em] text-[var(--black)]">
                        {statusLabels[milestone.status]}
                      </span>
                      <span className="font-mono text-[11px] text-[var(--gray-400)]">
                        {milestone.date}
                      </span>
                    </div>
                    <h3
                      className="text-[16px] text-[var(--black)] mb-2"
                      style={{ fontFamily: "var(--font-serif)" }}
                    >
                      {milestone.title}
                    </h3>
                    <p className="text-[13px] text-[var(--gray-500)] leading-relaxed mb-4">
                      {milestone.description}
                    </p>
                    <ul className="space-y-1.5">
                      {milestone.features.map((feat) => (
                        <li
                          key={feat}
                          className="flex items-center gap-2 text-[12px] text-[var(--gray-400)]"
                        >
                          <span className="h-1 w-1 bg-[var(--gray-300)] shrink-0" />
                          {feat}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              </FadeIn>
            );
          })}
        </div>
      </div>
    </section>
  );
}
