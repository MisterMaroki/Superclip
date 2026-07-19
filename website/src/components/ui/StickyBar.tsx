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
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-0 left-0 right-0 z-50 pointer-events-none"
        >
          <div className="pointer-events-auto mx-auto max-w-[var(--container)] px-4 pb-5">
            <div className="flex items-center justify-between gap-4 border border-[var(--gray-200)] bg-[var(--white)] px-5 py-3">
              <div className="hidden sm:flex items-center gap-3 min-w-0">
                <svg className="h-7 w-7 shrink-0" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
                  <rect width="512" height="512" fill="var(--black)"/>
                  <rect x="48" y="232" width="416" height="232" fill="var(--white)"/>
                  <rect x="96" y="276" width="224" height="20" fill="var(--black)"/>
                  <rect x="96" y="324" width="320" height="20" fill="var(--black)" opacity="0.45"/>
                  <rect x="96" y="372" width="176" height="20" fill="var(--black)" opacity="0.15"/>
                </svg>
                <div className="min-w-0">
                  <p className="font-mono text-[13px] uppercase tracking-[0.1em] text-[var(--black)] truncate">
                    Superclip
                  </p>
                  <p className="text-[11px] text-[var(--gray-400)] truncate">
                    <span className="font-medium text-[var(--black)]">
                      743 free spots
                    </span>{" "}
                    remaining
                  </p>
                </div>
              </div>

              {/* Mobile: just the counter */}
              <p className="sm:hidden text-[12px] text-[var(--gray-500)]">
                <span className="font-semibold text-[var(--black)]">743</span>{" "}
                free spots left
              </p>

              <a
                href="#download"
                className="inline-flex h-10 items-center gap-2 border border-[var(--black)] bg-[var(--black)] px-5 text-[13px] font-medium tracking-[0.025em] text-[var(--white)] transition-colors duration-150 hover:bg-[var(--gray-800)] shrink-0"
              >
                <svg
                  className="h-3.5 w-3.5"
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
                Download Free
              </a>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
