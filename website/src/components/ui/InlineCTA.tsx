"use client";

import { FadeIn } from "../effects/FadeIn";

interface InlineCTAProps {
  text: string;
  buttonText?: string;
  href?: string;
}

export function InlineCTA({
  text,
  buttonText = "Download Free",
  href = "#download",
}: InlineCTAProps) {
  return (
    <FadeIn>
      <div className="mt-16 flex flex-col sm:flex-row items-center justify-center gap-4 text-center">
        <p className="text-[14px] text-white/35">{text}</p>
        <a
          href={href}
          className="inline-flex h-10 items-center gap-2 rounded-full px-5 text-[13px] font-semibold text-white transition-all duration-200 hover:brightness-110 shrink-0"
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
          {buttonText}
        </a>
      </div>
    </FadeIn>
  );
}
