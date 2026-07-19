"use client";

import { FadeIn } from "../effects/FadeIn";

const rows = [
  {
    feature: "Price",
    superclip: "$14.99/yr",
    paste: "$29.99/yr",
    highlight: true,
  },
  { feature: "Clipboard History & Pinboards", superclip: true, paste: true },
  { feature: "OCR & Paste Stack", superclip: true, paste: true },
  {
    feature: "Snippets & Text Expansion",
    superclip: true,
    paste: false,
    highlight: true,
  },
  {
    feature: "Quick Actions & Smart Filters",
    superclip: true,
    paste: false,
    highlight: true,
  },
  {
    feature: "Screen Capture & Recording",
    superclip: "Feb '26",
    paste: false,
    highlight: true,
  },
  { feature: "iOS Companion App", superclip: "March '26", paste: true },
];

function Cell({ value }: { value: string | boolean }) {
  if (typeof value === "string") {
    return <span className="font-medium">{value}</span>;
  }
  return value ? (
    <svg
      className="h-4 w-4 text-[var(--black)]"
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
  ) : (
    <svg
      className="h-4 w-4 text-[var(--gray-300)]"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M6 18L18 6M6 6l12 12"
      />
    </svg>
  );
}

export function Comparison() {
  return (
    <section id="compare" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-10">
        <FadeIn>
          <div className="text-center mb-16">
            <p className="section-label mb-4">Compare</p>
            <h2 style={{ fontSize: "clamp(32px, 5vw, 48px)" }}>
              Same features. Half the price.
            </h2>
            <p className="mt-4 text-[17px] text-[var(--gray-500)] max-w-lg mx-auto">
              Everything Paste does, Superclip does too &mdash; for $14.99/yr
              instead of $29.99.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.1}>
          <div className="border border-[var(--gray-200)] overflow-hidden">
            {/* Table Header */}
            <div className="grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center border-b border-[var(--gray-200)] bg-[var(--gray-100)] px-6 py-4">
              <span className="font-mono text-[11px] uppercase tracking-[0.1em] text-[var(--gray-500)]">
                Feature
              </span>
              <span className="text-center">
                <span className="inline-flex items-center gap-1.5">
                  <svg className="h-4 w-4" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
                    <rect width="512" height="512" fill="var(--black)"/>
                    <rect x="48" y="232" width="416" height="232" fill="var(--white)"/>
                    <rect x="96" y="276" width="224" height="20" fill="var(--black)"/>
                    <rect x="96" y="324" width="320" height="20" fill="var(--black)" opacity="0.45"/>
                    <rect x="96" y="372" width="176" height="20" fill="var(--black)" opacity="0.15"/>
                  </svg>
                  <span className="text-[13px] font-medium text-[var(--black)]">
                    Superclip
                  </span>
                </span>
              </span>
              <span className="text-center text-[13px] text-[var(--gray-400)]">
                Paste
              </span>
            </div>

            {/* Table Rows */}
            {rows.map((row, i) => (
              <div
                key={row.feature}
                className={`grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center px-6 py-3.5
                  ${i !== rows.length - 1 ? "border-b border-[var(--gray-200)]" : ""}
                  ${row.highlight ? "bg-[var(--gray-100)]" : ""}
                `}
              >
                <span
                  className={`text-[13px] ${row.highlight ? "font-medium text-[var(--black)]" : "text-[var(--gray-600)]"}`}
                >
                  {row.feature}
                </span>
                <span className="flex justify-center text-[13px] text-[var(--black)]">
                  <Cell value={row.superclip} />
                </span>
                <span className="flex justify-center text-[13px] text-[var(--gray-500)]">
                  <Cell value={row.paste} />
                </span>
              </div>
            ))}

            {/* Price summary row */}
            <div className="border-t border-[var(--gray-200)] bg-[var(--gray-100)] px-6 py-4">
              <div className="grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center">
                <span className="text-[13px] font-bold text-[var(--black)]">
                  You save
                </span>
                <span className="text-center text-[14px] font-bold text-[var(--black)]">
                  $15/yr
                </span>
                <span className="text-center text-[13px] text-[var(--gray-300)]">
                  &mdash;
                </span>
              </div>
            </div>
          </div>
        </FadeIn>

        {/* CleanShot X callout */}
        <FadeIn delay={0.2}>
          <div className="mt-10 border border-[var(--gray-200)] p-8">
            <div className="flex flex-col md:flex-row md:items-center gap-6">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-3">
                  <span className="inline-flex h-5 items-center border border-[var(--gray-700)] px-2.5 font-mono text-[10px] uppercase tracking-[0.1em] text-[var(--black)]">
                    Coming Feb &apos;26
                  </span>
                  <span className="inline-flex h-5 items-center border border-[var(--gray-300)] px-2.5 font-mono text-[10px] uppercase tracking-[0.1em] text-[var(--gray-500)]">
                    Included free
                  </span>
                </div>
                <h3
                  className="text-xl text-[var(--black)] mb-2"
                  style={{ fontFamily: "var(--font-serif)" }}
                >
                  Built-in screen capture &amp; recording
                </h3>
                <p className="text-[14px] text-[var(--gray-500)] leading-relaxed max-w-lg">
                  Screenshots, GIF &amp; MP4 recording, scrolling capture, and a
                  full image &amp; video editor for your captures. The same
                  features CleanShot&nbsp;X charges{" "}
                  <span className="text-[var(--black)] font-medium">
                    $99/yr
                  </span>{" "}
                  for &mdash; bundled into Superclip at no extra cost.
                </p>
              </div>
              <div className="shrink-0 flex flex-col items-center gap-2 text-center">
                <div className="flex items-baseline gap-1">
                  <span className="text-[13px] text-[var(--gray-400)] line-through">
                    $99/yr
                  </span>
                  <span className="text-[11px] text-[var(--gray-400)]">
                    CleanShot X
                  </span>
                </div>
                <div className="flex items-baseline gap-1">
                  <span className="text-2xl font-bold text-[var(--black)]">
                    $0
                  </span>
                  <span className="text-[12px] text-[var(--gray-500)]">
                    with Superclip
                  </span>
                </div>
              </div>
            </div>

            {/* Feature chips */}
            <div className="mt-6 flex flex-wrap gap-2">
              {[
                "Screenshot capture",
                "GIF recording",
                "MP4 recording",
                "Scrolling capture",
                "Image editor",
                "Video editor",
                "Annotations & markup",
                "Quick copy & share",
              ].map((feat) => (
                <span
                  key={feat}
                  className="inline-flex h-7 items-center border border-[var(--gray-200)] px-3 font-mono text-[11px] text-[var(--gray-500)]"
                >
                  {feat}
                </span>
              ))}
            </div>
          </div>
        </FadeIn>

        <FadeIn delay={0.3}>
          <div className="mt-8 text-center">
            <p className="text-[14px] text-[var(--gray-500)]">
              Paste + CleanShot X ={" "}
              <span className="text-[var(--black)] font-medium">$129/yr</span>.
              Superclip ={" "}
              <span className="text-[var(--black)] font-bold">$14.99/yr</span>.
            </p>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
