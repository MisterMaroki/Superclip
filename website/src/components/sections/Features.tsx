"use client";

import { FadeIn } from "../effects/FadeIn";
import { InlineCTA } from "../ui/InlineCTA";

const features = [
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    gradient: "from-cyan-400 to-blue-500",
    title: "Lightning Fast",
    description:
      "Native SwiftUI. No Electron. Launches in 0.3s. Uses less than 30MB of RAM.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z" />
      </svg>
    ),
    gradient: "from-purple-400 to-violet-500",
    title: "Keyboard-First",
    description:
      "Global hotkeys for everything. Navigate, search, and paste without touching your mouse.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
      </svg>
    ),
    gradient: "from-emerald-400 to-green-500",
    title: "Private by Default",
    description:
      "Everything stays on your Mac. Exclude sensitive apps. Auto-clear on quit. Zero tracking.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z" />
      </svg>
    ),
    gradient: "from-pink-400 to-rose-500",
    title: "Paste Stack",
    description:
      "Copy multiple items, paste them in sequence. Auto-advances. Perfect for filling forms.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 3.75H6A2.25 2.25 0 003.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0120.25 6v1.5m0 9V18A2.25 2.25 0 0118 20.25h-1.5m-9 0H6A2.25 2.25 0 013.75 18v-1.5M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    ),
    gradient: "from-sky-400 to-cyan-500",
    title: "Built-in OCR",
    description:
      "Extract text from images and screen regions. No separate subscription needed.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />
      </svg>
    ),
    gradient: "from-violet-400 to-indigo-500",
    title: "Pinboards",
    description:
      "Pin items to color-coded collections. Quick-access from the sidebar. Always there.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25H12" />
      </svg>
    ),
    gradient: "from-amber-400 to-orange-500",
    title: "Snippets",
    description:
      "Define trigger shortcuts that expand into full text. Type ;;email in any app and it becomes your address.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    gradient: "from-rose-400 to-pink-500",
    title: "Quick Actions",
    description:
      "Superclip recognizes what you copy. Convert colors between hex, RGB, and HSL. Pretty print JSON. Contextual actions for emails, phones, and file paths.",
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 01-.659 1.591l-5.432 5.432a2.25 2.25 0 00-.659 1.591v2.927a2.25 2.25 0 01-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 00-.659-1.591L3.659 7.409A2.25 2.25 0 013 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0112 3z" />
      </svg>
    ),
    gradient: "from-teal-400 to-emerald-500",
    title: "Smart Filters",
    description:
      "Auto-tags your clipboard items — colors, code, emails, JSON, phone numbers. Filter your history by type instantly.",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-32">
      <div
        className="pointer-events-none absolute top-0 left-1/2 -translate-x-1/2 h-[1px] w-[600px]"
        style={{
          background:
            "linear-gradient(90deg, transparent, rgba(0,212,255,0.2), transparent)",
        }}
        aria-hidden
      />

      <div className="mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center mb-20">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-cyan-400/70 mb-4">
              Features
            </p>
            <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
              Everything you need.
              <br />
              <span className="text-white/40">Nothing you don&apos;t.</span>
            </h2>
          </div>
        </FadeIn>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature, i) => (
            <FadeIn key={feature.title} delay={i * 0.06}>
              <div className="group glass glass-hover h-full p-6 transition-all duration-300 hover:translate-y-[-2px]">
                <div
                  className={`mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br ${feature.gradient} text-white shadow-lg`}
                  style={{
                    boxShadow: `0 8px 24px -4px rgba(0,0,0,0.3)`,
                  }}
                >
                  {feature.icon}
                </div>
                <h3 className="mb-2 text-[15px] font-semibold text-white/90">
                  {feature.title}
                </h3>
                <p className="text-[13px] leading-relaxed text-white/40">
                  {feature.description}
                </p>
              </div>
            </FadeIn>
          ))}
        </div>

        <InlineCTA text="All of this, completely free." />
      </div>
    </section>
  );
}
