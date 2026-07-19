"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { FadeIn } from "../effects/FadeIn";

export function Pricing() {
  const [billing, setBilling] = useState<"monthly" | "annual">("annual");

  const price = billing === "annual" ? "$14.99" : "$1.99";
  const period = billing === "annual" ? "/year" : "/month";
  const pastePrice = billing === "annual" ? "$29.99/yr" : "$3.99/mo";
  const savings = "Save 50% vs Paste";
  const annualNote =
    billing === "monthly"
      ? "$1.99/mo vs $3.99/mo for Paste"
      : "$14.99/yr vs $29.99/yr for Paste";

  return (
    <section id="pricing" className="relative py-32">
      <div className="relative z-10 mx-auto max-w-[var(--container)] px-10">
        <FadeIn>
          <div className="text-center mb-16">
            <p className="section-label mb-4">Pricing</p>
            <h2 style={{ fontSize: "clamp(32px, 5vw, 48px)" }}>
              Free right now. Cheap forever.
            </h2>
            <p className="mt-4 text-[17px] text-[var(--gray-500)] max-w-md mx-auto">
              One plan. All features. No upsells.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.1}>
          <div className="max-w-[480px] mx-auto">
            {/* Free card */}
            <div className="border border-[var(--gray-200)] p-8">
              {/* Urgency bar */}
              <div className="flex items-center gap-3 mb-8 border border-[var(--gray-200)] bg-[var(--gray-100)] px-4 py-3">
                <span className="inline-block h-2 w-2 bg-[var(--black)] shrink-0" />
                <p className="text-[13px] text-[var(--gray-600)]">
                  <span className="font-bold text-[var(--black)]">
                    743 of 1,000
                  </span>{" "}
                  free spots still available
                </p>
              </div>

              {/* Price */}
              <div className="text-center mb-2">
                <span
                  className="text-6xl"
                  style={{ fontFamily: "var(--font-serif)" }}
                >
                  Free
                </span>
              </div>
              <p className="text-center text-[14px] text-[var(--gray-500)] mb-8">
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
                      className="mt-0.5 h-4 w-4 shrink-0 text-[var(--black)]"
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
                    <span className="text-[14px] text-[var(--gray-600)]">
                      {item}
                    </span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              <a
                href="#download"
                className="flex h-12 w-full items-center justify-center border border-[var(--black)] bg-[var(--black)] text-[15px] font-medium tracking-[0.025em] text-[var(--white)] transition-colors duration-150 hover:bg-[var(--gray-800)]"
              >
                Download Free
              </a>

              <div className="mt-4 flex items-center justify-center gap-4 text-[11px] text-[var(--gray-400)]">
                <span>No account needed</span>
                <span className="h-3 w-px bg-[var(--gray-200)]" />
                <span>No credit card</span>
                <span className="h-3 w-px bg-[var(--gray-200)]" />
                <span>macOS 14+</span>
              </div>
            </div>

            {/* After free — paid pricing */}
            <div className="mt-6 border border-[var(--gray-200)] p-6">
              <p className="text-center font-mono text-[11px] uppercase tracking-[0.1em] text-[var(--gray-500)] mb-5">
                After 1,000 spots are claimed
              </p>

              {/* Billing toggle */}
              <div className="flex items-center justify-center gap-1 mb-6">
                <div className="inline-flex border border-[var(--gray-200)] p-0.5">
                  <button
                    onClick={() => setBilling("monthly")}
                    className={`relative px-4 py-1.5 text-[13px] font-medium transition-all duration-150 ${
                      billing === "monthly"
                        ? "bg-[var(--black)] text-[var(--white)]"
                        : "text-[var(--gray-500)] hover:text-[var(--black)]"
                    }`}
                  >
                    Monthly
                  </button>
                  <button
                    onClick={() => setBilling("annual")}
                    className={`relative px-4 py-1.5 text-[13px] font-medium transition-all duration-150 ${
                      billing === "annual"
                        ? "bg-[var(--black)] text-[var(--white)]"
                        : "text-[var(--gray-500)] hover:text-[var(--black)]"
                    }`}
                  >
                    Annual
                  </button>
                </div>
                {billing === "annual" && (
                  <motion.span
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="ml-2 inline-flex h-5 items-center border border-[var(--gray-700)] px-2 font-mono text-[10px] uppercase tracking-[0.1em] text-[var(--black)]"
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
                  <span
                    className="text-4xl"
                    style={{ fontFamily: "var(--font-serif)" }}
                  >
                    {price}
                  </span>
                  <span className="text-lg text-[var(--gray-400)] ml-1">
                    {period}
                  </span>
                </motion.div>
              </div>

              <div className="flex items-center justify-center gap-3 text-[13px]">
                <span className="text-[var(--gray-400)] line-through">
                  {pastePrice} Paste
                </span>
                <span className="text-[var(--black)] font-medium">
                  {savings}
                </span>
              </div>

              <p className="mt-3 text-center text-[12px] text-[var(--gray-400)]">
                {annualNote}. Same features, half the price.
              </p>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
