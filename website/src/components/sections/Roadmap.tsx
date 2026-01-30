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

const statusStyles = {
  current: {
    dot: "bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.5)]",
    line: "bg-emerald-400/30",
    badge: "bg-emerald-500/15 text-emerald-400",
    badgeLabel: "Now",
  },
  upcoming: {
    dot: "bg-cyan-400 shadow-[0_0_8px_rgba(0,212,255,0.4)]",
    line: "bg-cyan-400/20",
    badge: "bg-cyan-500/15 text-cyan-400",
    badgeLabel: "Next",
  },
  future: {
    dot: "bg-purple-400 shadow-[0_0_8px_rgba(139,92,246,0.4)]",
    line: "bg-purple-400/15",
    badge: "bg-purple-500/15 text-purple-400",
    badgeLabel: "Soon",
  },
};

export function Roadmap() {
  return (
    <section id="roadmap" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center mb-20">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-cyan-400/70 mb-4">
              Roadmap
            </p>
            <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
              Where we&apos;re headed
            </h2>
            <p className="mt-4 text-lg text-white/40 max-w-lg mx-auto">
              Superclip is growing fast. Here&apos;s what&apos;s coming &mdash; and after
              that, you decide.
            </p>
          </div>
        </FadeIn>

        <div className="relative max-w-[680px] mx-auto">
          {/* Timeline line */}
          <div className="absolute left-[19px] md:left-1/2 md:-translate-x-px top-0 bottom-0 w-px bg-gradient-to-b from-emerald-400/30 via-cyan-400/20 to-purple-400/10" />

          {milestones.map((milestone, i) => {
            const style = statusStyles[milestone.status];
            const isEven = i % 2 === 0;

            return (
              <FadeIn key={milestone.title} delay={i * 0.1}>
                <div
                  className={`relative flex items-start gap-6 mb-12 last:mb-0
                    md:gap-0 ${isEven ? "md:flex-row" : "md:flex-row-reverse"}
                  `}
                >
                  {/* Dot */}
                  <div className="absolute left-[15px] md:left-1/2 md:-translate-x-1/2 top-1 z-10">
                    <div className={`h-[10px] w-[10px] rounded-full ${style.dot}`} />
                  </div>

                  {/* Card */}
                  <div
                    className={`ml-10 md:ml-0 md:w-[calc(50%-32px)] glass p-6 transition-all duration-200 hover:translate-y-[-2px] glass-hover`}
                  >
                    <div className="flex items-center gap-2 mb-3">
                      <span
                        className={`inline-flex h-5 items-center rounded-full px-2 text-[10px] font-bold uppercase tracking-wider ${style.badge}`}
                      >
                        {style.badgeLabel}
                      </span>
                      <span className="text-[12px] text-white/30">
                        {milestone.date}
                      </span>
                    </div>
                    <h3 className="text-[16px] font-bold text-white/90 mb-2">
                      {milestone.title}
                    </h3>
                    <p className="text-[13px] text-white/40 leading-relaxed mb-4">
                      {milestone.description}
                    </p>
                    <ul className="space-y-1.5">
                      {milestone.features.map((feat) => (
                        <li
                          key={feat}
                          className="flex items-center gap-2 text-[12px] text-white/35"
                        >
                          <span className="h-1 w-1 rounded-full bg-white/20 shrink-0" />
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
