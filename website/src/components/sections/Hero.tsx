"use client";

import { motion } from "framer-motion";
import { GradientBackground } from "../effects/GradientBackground";
import { Badge } from "../ui/Badge";
import { KeyboardKey } from "../ui/KeyboardKey";

export function Hero() {
  return (
    <section className="relative min-h-[100dvh] flex items-center justify-center overflow-hidden">
      <GradientBackground />

      <div className="relative z-10 mx-auto max-w-[var(--container)] px-6 pt-24 pb-20 text-center">
        {/* Badge with urgency */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: [0.25, 0.1, 0.25, 1] }}
        >
          <Badge variant="gradient">
            <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-emerald-400 font-bold">743 of 1,000</span>{" "}
            free spots remaining
          </Badge>
        </motion.div>

        {/* Headline */}
        <motion.h1
          className="mt-8 text-5xl sm:text-6xl md:text-7xl lg:text-[80px] font-extrabold tracking-tight leading-[1.05]"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{
            duration: 0.7,
            delay: 0.1,
            ease: [0.25, 0.1, 0.25, 1],
          }}
        >
          Your clipboard,{" "}
          <span className="gradient-text">supercharged</span>
        </motion.h1>

        {/* Subheadline — benefit-driven */}
        <motion.p
          className="mt-6 mx-auto max-w-[540px] text-lg md:text-xl text-white/50 font-normal leading-relaxed"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.25 }}
        >
          Every feature of Paste &mdash; at half the price. Plus built-in screen
          capture worth $99/yr.{" "}
          <span className="text-white/70 font-medium">Free for early adopters.</span>
        </motion.p>

        {/* Primary CTA */}
        <motion.div
          className="mt-10 flex flex-col items-center gap-4"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.4 }}
        >
          <a
            href="#download"
            className="group relative inline-flex h-14 items-center gap-2.5 rounded-full px-9 text-[16px] font-semibold text-white transition-all duration-200 hover:brightness-110 hover:scale-[1.02] glow-btn"
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

          {/* Trust signals */}
          <div className="flex flex-wrap items-center justify-center gap-x-5 gap-y-1 text-[12px] text-white/25">
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
          </div>
        </motion.div>

        {/* Keyboard Shortcut Hint */}
        <motion.div
          className="mt-6 flex items-center justify-center gap-2 text-white/30 text-[13px]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.6 }}
        >
          Press
          <KeyboardKey glow>&#8984;</KeyboardKey>
          <KeyboardKey glow>&#8679;</KeyboardKey>
          <KeyboardKey glow>A</KeyboardKey>
          to open anywhere
        </motion.div>

        {/* App Preview */}
        <motion.div
          className="mt-16 mx-auto max-w-[900px]"
          initial={{ opacity: 0, y: 60, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{
            duration: 0.9,
            delay: 0.5,
            ease: [0.25, 0.1, 0.25, 1],
          }}
        >
          <div className="relative rounded-2xl border border-white/[0.08] bg-white/[0.02] p-1 shadow-2xl shadow-black/50">
            {/* Window chrome */}
            <div className="flex items-center gap-2 px-4 py-3 border-b border-white/[0.06]">
              <div className="h-3 w-3 rounded-full bg-white/[0.08]" />
              <div className="h-3 w-3 rounded-full bg-white/[0.08]" />
              <div className="h-3 w-3 rounded-full bg-white/[0.08]" />
              <span className="ml-3 text-[11px] text-white/25 font-medium">
                Superclip
              </span>
            </div>
            {/* Simulated Interface */}
            <div className="p-6 space-y-3">
              {/* Search bar */}
              <div className="flex items-center gap-3 rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3">
                <svg className="h-4 w-4 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <span className="text-[13px] text-white/25">Search clipboard history...</span>
                <div className="ml-auto flex gap-1">
                  <KeyboardKey>&#8984;</KeyboardKey>
                  <KeyboardKey>F</KeyboardKey>
                </div>
              </div>
              {/* Clipboard Items */}
              {[
                {
                  icon: "T",
                  iconColor: "from-cyan-400 to-blue-500",
                  title: "API Documentation Notes",
                  subtitle: "Copied from VS Code",
                  time: "2s ago",
                  active: true,
                },
                {
                  icon: "\uD83D\uDD17",
                  iconColor: "from-purple-400 to-pink-500",
                  title: "https://developer.apple.com/swiftui",
                  subtitle: "Copied from Safari",
                  time: "1m ago",
                  active: false,
                },
                {
                  icon: "\uD83D\uDDBC",
                  iconColor: "from-orange-400 to-red-500",
                  title: "Screenshot 2024-01-30",
                  subtitle: "Copied from Finder",
                  time: "3m ago",
                  active: false,
                },
                {
                  icon: "{ }",
                  iconColor: "from-emerald-400 to-teal-500",
                  title: '{ "status": 200, "data": [...] }',
                  subtitle: "Copied from Terminal",
                  time: "5m ago",
                  active: false,
                },
              ].map((item, i) => (
                <div
                  key={i}
                  className={`flex items-center gap-4 rounded-xl px-4 py-3 transition-colors ${
                    item.active
                      ? "bg-gradient-to-r from-cyan-500/[0.08] to-purple-500/[0.06] border border-cyan-500/20"
                      : "border border-transparent hover:bg-white/[0.03]"
                  }`}
                >
                  <div
                    className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br ${item.iconColor} text-[12px] font-bold text-white`}
                  >
                    {item.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p
                      className={`truncate text-[13px] font-medium ${item.active ? "text-white/90" : "text-white/60"}`}
                    >
                      {item.title}
                    </p>
                    <p className="text-[11px] text-white/30">{item.subtitle}</p>
                  </div>
                  <span className="shrink-0 text-[11px] text-white/20">
                    {item.time}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Subtle reflection */}
          <div
            className="mt-1 h-32 rounded-2xl opacity-30"
            style={{
              background:
                "linear-gradient(to bottom, rgba(255,255,255,0.015), transparent)",
              filter: "blur(1px)",
              transform: "scaleY(-0.3)",
            }}
          />
        </motion.div>
      </div>
    </section>
  );
}
