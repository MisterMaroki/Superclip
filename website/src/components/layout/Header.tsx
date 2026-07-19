"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";

const navLinks = [
  { label: "Home", href: "/" },
  { label: "Docs", href: "/docs" },
  { label: "Blog", href: "/blog" },
];

export function Header() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className="fixed top-0 left-0 right-0 z-50 bg-[var(--white)] transition-[border-color] duration-300"
      style={{
        borderBottom: scrolled
          ? "1px solid var(--gray-200)"
          : "1px solid transparent",
      }}
    >
      <nav className="mx-auto flex h-16 max-w-[var(--container)] items-center justify-between px-10">
        {/* Logo */}
        <a href="/" className="flex items-center gap-2.5">
          <svg className="h-7 w-7" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
            <rect width="512" height="512" fill="var(--black)"/>
            <rect x="48" y="232" width="416" height="232" fill="var(--white)"/>
            <rect x="96" y="276" width="224" height="20" fill="var(--black)"/>
            <rect x="96" y="324" width="320" height="20" fill="var(--black)" opacity="0.45"/>
            <rect x="96" y="372" width="176" height="20" fill="var(--black)" opacity="0.15"/>
          </svg>
          <span className="font-mono text-[13px] font-normal uppercase tracking-[0.1em] text-[var(--black)]">
            Superclip
          </span>
        </a>

        {/* Desktop Nav */}
        <ul className="hidden md:flex items-center gap-8">
          {navLinks.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                className="text-[14px] text-[var(--gray-500)] transition-colors duration-150 hover:text-[var(--black)]"
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>

        {/* CTA */}
        <div className="hidden md:flex items-center gap-3">
          <a
            href="/#pricing"
            className="inline-flex h-9 items-center border border-[var(--gray-300)] bg-transparent px-5 text-[14px] font-medium text-[var(--gray-600)] transition-colors duration-150 hover:border-[var(--black)] hover:text-[var(--black)]"
          >
            Pricing
          </a>
          <a
            href="/#download"
            className="inline-flex h-9 items-center border border-[var(--black)] bg-[var(--black)] px-5 text-[14px] font-medium text-[var(--white)] transition-colors duration-150 hover:bg-[var(--gray-800)]"
          >
            Download
          </a>
        </div>

        {/* Mobile Toggle */}
        <button
          className="md:hidden flex flex-col gap-1.5 p-2"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
        >
          <span
            className={`block h-px w-5 bg-[var(--black)] transition-transform duration-200 ${mobileOpen ? "translate-y-[3.5px] rotate-45" : ""}`}
          />
          <span
            className={`block h-px w-5 bg-[var(--black)] transition-opacity duration-200 ${mobileOpen ? "opacity-0" : ""}`}
          />
          <span
            className={`block h-px w-5 bg-[var(--black)] transition-transform duration-200 ${mobileOpen ? "-translate-y-[3.5px] -rotate-45" : ""}`}
          />
        </button>
      </nav>

      {/* Mobile Menu */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="md:hidden overflow-hidden border-t border-[var(--gray-200)] bg-[var(--white)]"
          >
            <div className="flex flex-col gap-1 p-4">
              {navLinks.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileOpen(false)}
                  className="px-4 py-2.5 text-[14px] text-[var(--gray-600)] transition-colors hover:text-[var(--black)]"
                >
                  {link.label}
                </a>
              ))}
              <div className="mt-2 pt-2 border-t border-[var(--gray-200)]">
                <a
                  href="/#download"
                  onClick={() => setMobileOpen(false)}
                  className="flex items-center justify-center border border-[var(--black)] bg-[var(--black)] py-2.5 text-[14px] font-medium text-[var(--white)]"
                >
                  Download Free
                </a>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
