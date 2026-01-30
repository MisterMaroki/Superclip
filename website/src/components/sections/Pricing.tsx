"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { FadeIn } from "../effects/FadeIn";

export function Pricing() {
  const [billing, setBilling] = useState<"monthly" | "annual">("annual");

  const price = billing === "annual" ? "$14.99" : "$1.99";
  const period = billing === "annual" ? "/year" : "/month";
  const pastePrice = billing === "annual" ? "$29.99/yr" : "$3.99/mo";
  const savings = billing === "annual" ? "Save 50% vs Paste" : "Save 50% vs Paste";
  const annualNote = billing === "monthly" ? "$1.99/mo vs $3.99/mo for Paste" : "$14.99/yr vs $29.99/yr for Paste";

  return (
    <section id="pricing" className="relative py-32">
      <div
        className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-[600px] w-[600px] rounded-full opacity-[0.04]"
        style={{
          background:
            "radial-gradient(circle, var(--purple) 0%, transparent 70%)",
        }}
        aria-hidden
      />

      <div className="relative z-10 mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center mb-16">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-emerald-400/70 mb-4">
              Pricing
            </p>
            <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
              Free right now. Cheap forever.
            </h2>
            <p className="mt-4 text-lg text-white/40 max-w-md mx-auto">
              One plan. All features. No upsells.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.1}>
          <div className="max-w-[480px] mx-auto">
            {/* Free card */}
            <div className="glass p-8 relative overflow-hidden">
              <div
                className="absolute top-0 left-0 right-0 h-[1px]"
                style={{
                  background:
                    "linear-gradient(90deg, transparent, rgba(0,212,255,0.5), transparent)",
                }}
              />

              {/* Urgency bar */}
              <div className="flex items-center gap-3 mb-8 rounded-xl bg-emerald-500/[0.08] border border-emerald-500/20 px-4 py-3">
                <span className="inline-block h-2 w-2 rounded-full bg-emerald-400 animate-pulse shrink-0" />
                <p className="text-[13px] text-emerald-400/90">
                  <span className="font-bold">743 of 1,000</span> free spots
                  still available
                </p>
              </div>

              {/* Price */}
              <div className="text-center mb-2">
                <span className="text-6xl font-extrabold">Free</span>
              </div>
              <p className="text-center text-[14px] text-white/40 mb-8">
                For the first 1,000 users &mdash; forever.
              </p>

              {/* What's included */}
              <ul className="space-y-3 mb-8">
                {[
                  "Everything — no feature gates",
                  "Clipboard history, pinboards, paste stack",
                  "Built-in OCR & rich text editor",
                  "Screen capture & recording (coming Feb)",
                  "iOS companion app (coming March)",
                  "Free forever for early adopters",
                ].map((item) => (
                  <li key={item} className="flex items-start gap-3">
                    <svg
                      className="mt-0.5 h-4 w-4 shrink-0 text-cyan-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2.5}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M4.5 12.75l6 6 9-13.5"
                      />
                    </svg>
                    <span className="text-[14px] text-white/60">{item}</span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              <a
                href="#download"
                className="flex h-12 w-full items-center justify-center rounded-xl text-[15px] font-semibold text-white transition-all duration-200 hover:brightness-110 hover:scale-[1.01] glow-btn"
                style={{ background: "var(--gradient-primary)" }}
              >
                Download Free
              </a>

              <div className="mt-4 flex items-center justify-center gap-4 text-[11px] text-white/20">
                <span>No account needed</span>
                <span className="h-3 w-px bg-white/10" />
                <span>No credit card</span>
                <span className="h-3 w-px bg-white/10" />
                <span>macOS 12+</span>
              </div>
            </div>

            {/* After free — paid pricing */}
            <div className="mt-6 glass p-6 relative overflow-hidden">
              <div
                className="absolute top-0 left-0 right-0 h-[1px]"
                style={{
                  background:
                    "linear-gradient(90deg, transparent, rgba(139,92,246,0.3), transparent)",
                }}
              />

              <p className="text-center text-[12px] font-semibold uppercase tracking-widest text-white/30 mb-5">
                After 1,000 spots are claimed
              </p>

              {/* Billing toggle */}
              <div className="flex items-center justify-center gap-1 mb-6">
                <div className="inline-flex rounded-full border border-white/[0.08] bg-white/[0.03] p-0.5">
                  <button
                    onClick={() => setBilling("monthly")}
                    className={`relative rounded-full px-4 py-1.5 text-[13px] font-medium transition-all duration-200 ${
                      billing === "monthly"
                        ? "text-white"
                        : "text-white/40 hover:text-white/60"
                    }`}
                  >
                    {billing === "monthly" && (
                      <motion.div
                        layoutId="billing-pill"
                        className="absolute inset-0 rounded-full bg-white/[0.1] border border-white/[0.08]"
                        transition={{ type: "spring", duration: 0.4, bounce: 0.15 }}
                      />
                    )}
                    <span className="relative">Monthly</span>
                  </button>
                  <button
                    onClick={() => setBilling("annual")}
                    className={`relative rounded-full px-4 py-1.5 text-[13px] font-medium transition-all duration-200 ${
                      billing === "annual"
                        ? "text-white"
                        : "text-white/40 hover:text-white/60"
                    }`}
                  >
                    {billing === "annual" && (
                      <motion.div
                        layoutId="billing-pill"
                        className="absolute inset-0 rounded-full bg-white/[0.1] border border-white/[0.08]"
                        transition={{ type: "spring", duration: 0.4, bounce: 0.15 }}
                      />
                    )}
                    <span className="relative">Annual</span>
                  </button>
                </div>
                {billing === "annual" && (
                  <motion.span
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="ml-2 inline-flex h-5 items-center rounded-full bg-emerald-500/15 px-2 text-[10px] font-bold uppercase tracking-wider text-emerald-400"
                  >
                    Best value
                  </motion.span>
                )}
              </div>

              {/* Price display */}
              <div className="text-center mb-4">
                <motion.div
                  key={billing}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.2 }}
                >
                  <span className="text-4xl font-extrabold">{price}</span>
                  <span className="text-lg text-white/30 ml-1">{period}</span>
                </motion.div>
              </div>

              <div className="flex items-center justify-center gap-3 text-[13px]">
                <span className="text-white/30 line-through">{pastePrice} Paste</span>
                <span className="text-emerald-400/70 font-semibold">{savings}</span>
              </div>

              <p className="mt-3 text-center text-[12px] text-white/20">
                {annualNote}. Same features, half the price.
              </p>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
