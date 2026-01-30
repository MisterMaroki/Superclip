"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";

export function StickyBar() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      setVisible(window.scrollY > 600);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          transition={{ duration: 0.3, ease: "easeOut" }}
          className="fixed bottom-0 left-0 right-0 z-50 pointer-events-none"
        >
          <div className="pointer-events-auto mx-auto max-w-[var(--container)] px-4 pb-5">
            <div
              className="flex items-center justify-between gap-4 rounded-2xl border border-white/[0.08] px-5 py-3 shadow-2xl shadow-black/60"
              style={{
                background: "rgba(5, 5, 7, 0.88)",
                backdropFilter: "blur(24px) saturate(180%)",
                WebkitBackdropFilter: "blur(24px) saturate(180%)",
              }}
            >
              <div className="hidden sm:flex items-center gap-3 min-w-0">
                <img
                  src="/app-icon.jpeg"
                  alt="Superclip"
                  className="h-8 w-8 shrink-0 rounded-lg"
                />
                <div className="min-w-0">
                  <p className="text-[13px] font-semibold text-white/80 truncate">
                    Superclip
                  </p>
                  <p className="text-[11px] text-white/30 truncate">
                    <span className="text-emerald-400/70 font-medium">743 free spots</span>
                    {" "}remaining
                  </p>
                </div>
              </div>

              {/* Mobile: just the counter */}
              <p className="sm:hidden text-[12px] text-white/40">
                <span className="text-emerald-400 font-semibold">743</span> free spots left
              </p>

              <a
                href="#download"
                className="inline-flex h-10 items-center gap-2 rounded-xl px-5 text-[13px] font-semibold text-white transition-all duration-200 hover:brightness-110 shrink-0"
                style={{ background: "var(--gradient-primary)" }}
              >
                <svg
                  className="h-3.5 w-3.5"
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
                Download Free
              </a>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
