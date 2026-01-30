"use client";

import { FadeIn } from "../effects/FadeIn";

const rows = [
  { feature: "Price", superclip: "$14.99/yr", paste: "$29.99/yr", highlight: true },
  { feature: "Clipboard History & Pinboards", superclip: true, paste: true },
  { feature: "OCR & Paste Stack", superclip: true, paste: true },
  { feature: "iOS Companion App", superclip: "March '26", paste: true },
  { feature: "Screen Capture & Recording", superclip: "Feb '26", paste: false, highlight: true },
];

function Cell({ value }: { value: string | boolean }) {
  if (typeof value === "string") {
    return <span className="font-semibold">{value}</span>;
  }
  return value ? (
    <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-emerald-500/15">
      <svg className="h-3 w-3 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </svg>
    </span>
  ) : (
    <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-white/[0.04]">
      <svg className="h-3 w-3 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </span>
  );
}

export function Comparison() {
  return (
    <section id="compare" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center mb-16">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-purple-400/70 mb-4">
              Compare
            </p>
            <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
              Same features. Half the price.
            </h2>
            <p className="mt-4 text-lg text-white/40 max-w-lg mx-auto">
              Everything Paste does, Superclip does too &mdash; for $14.99/yr
              instead of $29.99.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.15}>
          <div className="glass overflow-hidden">
            {/* Table Header */}
            <div className="grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center border-b border-white/[0.06] px-6 py-4">
              <span className="text-[12px] font-semibold uppercase tracking-wider text-white/30">
                Feature
              </span>
              <span className="text-center">
                <span className="inline-flex items-center gap-1.5">
                  <img src="/app-icon.jpeg" alt="" className="h-4 w-4 rounded" />
                  <span className="text-[13px] font-semibold text-white/80">
                    Superclip
                  </span>
                </span>
              </span>
              <span className="text-center text-[13px] font-medium text-white/40">
                Paste
              </span>
            </div>

            {/* Table Rows */}
            {rows.map((row, i) => (
              <div
                key={row.feature}
                className={`grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center px-6 py-3.5 transition-colors
                  ${i !== rows.length - 1 ? "border-b border-white/[0.04]" : ""}
                  ${row.highlight ? "bg-cyan-500/[0.03]" : "hover:bg-white/[0.02]"}
                `}
              >
                <span className={`text-[13px] ${row.highlight ? "font-semibold text-white/80" : "text-white/55"}`}>
                  {row.feature}
                </span>
                <span className="flex justify-center text-[13px] text-cyan-300">
                  <Cell value={row.superclip} />
                </span>
                <span className="flex justify-center text-[13px] text-white/45">
                  <Cell value={row.paste} />
                </span>
              </div>
            ))}

            {/* Price summary row */}
            <div className="border-t border-white/[0.08] bg-white/[0.02] px-6 py-4">
              <div className="grid grid-cols-[1fr_120px_120px] sm:grid-cols-[1fr_150px_150px] items-center">
                <span className="text-[13px] font-bold text-white/70">
                  You save
                </span>
                <span className="text-center text-[14px] font-bold text-emerald-400">
                  $15/yr
                </span>
                <span className="text-center text-[13px] text-white/25">
                  &mdash;
                </span>
              </div>
            </div>
          </div>
        </FadeIn>

        {/* CleanShot X callout */}
        <FadeIn delay={0.25}>
          <div className="mt-10 glass p-8 relative overflow-hidden">
            <div
              className="absolute top-0 left-0 right-0 h-[1px]"
              style={{
                background:
                  "linear-gradient(90deg, transparent, rgba(0,212,255,0.4), transparent)",
              }}
            />
            <div className="flex flex-col md:flex-row md:items-center gap-6">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-3">
                  <span className="inline-flex h-5 items-center rounded-full bg-cyan-500/15 px-2.5 text-[10px] font-bold uppercase tracking-wider text-cyan-400">
                    Coming Feb &apos;26
                  </span>
                  <span className="inline-flex h-5 items-center rounded-full bg-emerald-500/15 px-2.5 text-[10px] font-bold uppercase tracking-wider text-emerald-400">
                    Included free
                  </span>
                </div>
                <h3 className="text-xl font-bold text-white/90 mb-2">
                  Built-in screen capture &amp; recording
                </h3>
                <p className="text-[14px] text-white/45 leading-relaxed max-w-lg">
                  Screenshots, GIF &amp; MP4 recording, scrolling capture, and a full
                  image &amp; video editor for your captures. The same features
                  CleanShot&nbsp;X charges <span className="text-white/70 font-semibold">$99/yr</span> for
                  &mdash; bundled into Superclip at no extra cost.
                </p>
              </div>
              <div className="shrink-0 flex flex-col items-center gap-2 text-center">
                <div className="flex items-baseline gap-1">
                  <span className="text-[13px] text-white/30 line-through">$99/yr</span>
                  <span className="text-[11px] text-white/20">CleanShot X</span>
                </div>
                <div className="flex items-baseline gap-1">
                  <span className="text-2xl font-extrabold text-emerald-400">$0</span>
                  <span className="text-[12px] text-emerald-400/60">with Superclip</span>
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
                  className="inline-flex h-7 items-center rounded-full border border-white/[0.06] bg-white/[0.03] px-3 text-[12px] text-white/40"
                >
                  {feat}
                </span>
              ))}
            </div>
          </div>
        </FadeIn>

        <FadeIn delay={0.35}>
          <div className="mt-8 text-center">
            <p className="text-[14px] text-white/30">
              Paste + CleanShot X = <span className="text-white/50 font-medium">$129/yr</span>.
              Superclip = <span className="text-emerald-400 font-semibold">$14.99/yr</span>.
            </p>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
