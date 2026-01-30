"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { FadeIn } from "../effects/FadeIn";

const faqs = [
  {
    q: "Is Superclip really free?",
    a: "Yes. The first 1,000 users get Superclip completely free — forever. No trial, no credit card, no catch. After those spots are claimed, new users pay $14.99/year.",
  },
  {
    q: "How is this different from Paste?",
    a: "Superclip has every feature Paste has — clipboard history, pinboards, OCR, paste stack — at half the price. Plus we're adding built-in screen capture and recording (worth $99/yr with CleanShot X) for free.",
  },
  {
    q: "Is my clipboard data private?",
    a: "100%. Everything stays on your Mac. There's no cloud sync, no analytics, no tracking. You can exclude sensitive apps and auto-clear history on quit.",
  },
  {
    q: "Will it slow down my Mac?",
    a: "No. Superclip is built natively with SwiftUI — no Electron, no web wrappers. It uses less than 30MB of memory and launches in under 0.3 seconds.",
  },
  {
    q: "What if I already use Paste?",
    a: "You can run both side-by-side. Try Superclip free, and switch when you're ready. Your muscle memory transfers — same keyboard shortcuts, same workflows.",
  },
  {
    q: "What macOS versions are supported?",
    a: "Superclip requires macOS 12 (Monterey) or later. It runs natively on both Apple Silicon and Intel Macs.",
  },
];

function FAQItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);

  return (
    <div className="border-b border-white/[0.06] last:border-b-0">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between gap-4 py-5 text-left group"
      >
        <span className="text-[15px] font-semibold text-white/80 group-hover:text-white/95 transition-colors">
          {q}
        </span>
        <span className="shrink-0">
          <svg
            className={`h-4 w-4 text-white/30 transition-transform duration-200 ${open ? "rotate-45" : ""}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
        </span>
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25, ease: "easeInOut" }}
            className="overflow-hidden"
          >
            <p className="pb-5 text-[14px] text-white/45 leading-relaxed max-w-[600px]">
              {a}
            </p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function FAQ() {
  return (
    <section id="faq" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-6">
        <div className="max-w-[640px] mx-auto">
          <FadeIn>
            <div className="text-center mb-12">
              <p className="text-[13px] font-semibold uppercase tracking-widest text-white/30 mb-4">
                FAQ
              </p>
              <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight">
                Common questions
              </h2>
            </div>
          </FadeIn>

          <FadeIn delay={0.1}>
            <div className="glass p-2">
              <div className="px-6">
                {faqs.map((faq) => (
                  <FAQItem key={faq.q} q={faq.q} a={faq.a} />
                ))}
              </div>
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
