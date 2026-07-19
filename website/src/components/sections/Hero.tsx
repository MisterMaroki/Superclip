"use client";

import { motion } from "framer-motion";
import { Badge } from "../ui/Badge";
import { KeyboardKey } from "../ui/KeyboardKey";

export function Hero() {
  return (
    <section className="relative min-h-[100dvh] flex items-center justify-center">
      <div className="relative z-10 mx-auto max-w-[var(--container)] px-10 pt-24 pb-20 text-center">
        {/* Badge with urgency */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        >
          <Badge variant="emphasis">
            <span className="inline-block h-1.5 w-1.5 bg-[var(--black)]" />
            <span className="font-bold text-[var(--black)]">743 of 1,000</span>{" "}
            free spots remaining
          </Badge>
        </motion.div>

        {/* Headline */}
        <motion.h1
          className="mt-8"
          style={{ fontSize: "clamp(44px, 6vw, 72px)", lineHeight: 1.05 }}
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{
            duration: 0.5,
            delay: 0.1,
            ease: [0.16, 1, 0.3, 1],
          }}
        >
          Your clipboard, supercharged
        </motion.h1>

        {/* Subheadline */}
        <motion.p
          className="mt-6 mx-auto max-w-[540px] text-[17px] text-[var(--gray-600)] leading-relaxed"
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
        >
          Every feature of Paste &mdash; at half the price. Plus built-in screen
          capture worth $99/yr.{" "}
          <span className="text-[var(--black)] font-medium">
            Free for early adopters.
          </span>
        </motion.p>

        {/* Primary CTA */}
        <motion.div
          className="mt-10 flex flex-col items-center gap-4"
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
        >
          <a
            href="#download"
            className="inline-flex h-14 items-center gap-2.5 border border-[var(--black)] bg-[var(--black)] px-9 text-[16px] font-medium tracking-[0.025em] text-[var(--white)] transition-colors duration-150 hover:bg-[var(--gray-800)]"
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

          {/* Trust signals */}
          <div className="flex flex-wrap items-center justify-center gap-x-5 gap-y-1 text-[12px] text-[var(--gray-400)]">
            {["No account needed", "No credit card", "30-second setup"].map(
              (text) => (
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
              )
            )}
          </div>
        </motion.div>

        {/* Keyboard Shortcut Hint */}
        <motion.div
          className="mt-6 flex items-center justify-center gap-2 text-[var(--gray-400)] text-[13px]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.5 }}
        >
          Press
          <KeyboardKey>&#8984;</KeyboardKey>
          <KeyboardKey>&#8679;</KeyboardKey>
          <KeyboardKey>A</KeyboardKey>
          to open anywhere
        </motion.div>

        {/* App Preview */}
        <motion.div
          className="mt-16 mx-auto max-w-[900px]"
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{
            duration: 0.5,
            delay: 0.4,
            ease: [0.16, 1, 0.3, 1],
          }}
        >
          <div className="relative border border-[var(--gray-200)]">
            {/* Window chrome */}
            <div className="flex items-center gap-2 px-4 py-3 border-b border-[var(--gray-200)]">
              <div className="h-2.5 w-2.5 border border-[var(--gray-300)]" />
              <div className="h-2.5 w-2.5 border border-[var(--gray-300)]" />
              <div className="h-2.5 w-2.5 border border-[var(--gray-300)]" />
              <span className="ml-3 font-mono text-[11px] text-[var(--gray-400)]">
                Superclip
              </span>
            </div>
            {/* Simulated Interface */}
            <div className="p-6 space-y-0 bg-[var(--gray-200)]">
              {/* Search bar */}
              <div className="flex items-center gap-3 border border-[var(--gray-200)] bg-[var(--white)] px-4 py-3">
                <svg
                  className="h-4 w-4 text-[var(--gray-400)]"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
                <span className="text-[13px] text-[var(--gray-400)]">
                  Search clipboard history...
                </span>
                <div className="ml-auto flex gap-1">
                  <KeyboardKey>&#8984;</KeyboardKey>
                  <KeyboardKey>F</KeyboardKey>
                </div>
              </div>
              {/* Clipboard Items */}
              {[
                {
                  icon: "T",
                  title: "API Documentation Notes",
                  subtitle: "Copied from VS Code",
                  time: "2s ago",
                  active: true,
                },
                {
                  icon: "\u2197",
                  title: "https://developer.apple.com/swiftui",
                  subtitle: "Copied from Safari",
                  time: "1m ago",
                  active: false,
                },
                {
                  icon: "\u25A1",
                  title: "Screenshot 2024-01-30",
                  subtitle: "Copied from Finder",
                  time: "3m ago",
                  active: false,
                },
                {
                  icon: "{ }",
                  title: '{ "status": 200, "data": [...] }',
                  subtitle: "Copied from Terminal",
                  time: "5m ago",
                  active: false,
                },
              ].map((item, i) => (
                <div
                  key={i}
                  className={`flex items-center gap-4 px-4 py-3 transition-colors ${
                    item.active
                      ? "bg-[var(--black)] text-[var(--white)]"
                      : "bg-[var(--white)] hover:bg-[var(--gray-100)]"
                  }`}
                >
                  <div
                    className={`flex h-9 w-9 shrink-0 items-center justify-center border font-mono text-[12px] ${
                      item.active
                        ? "border-[var(--gray-700)] text-[var(--white)]"
                        : "border-[var(--gray-200)] text-[var(--gray-600)]"
                    }`}
                  >
                    {item.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p
                      className={`truncate text-[13px] font-medium ${item.active ? "text-[var(--white)]" : "text-[var(--black)]"}`}
                    >
                      {item.title}
                    </p>
                    <p
                      className={`text-[11px] ${item.active ? "text-[var(--gray-400)]" : "text-[var(--gray-400)]"}`}
                    >
                      {item.subtitle}
                    </p>
                  </div>
                  <span
                    className={`shrink-0 font-mono text-[11px] ${item.active ? "text-[var(--gray-500)]" : "text-[var(--gray-400)]"}`}
                  >
                    {item.time}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
