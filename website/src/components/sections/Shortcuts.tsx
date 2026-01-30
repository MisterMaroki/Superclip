"use client";

import { FadeIn } from "../effects/FadeIn";
import { KeyboardKey } from "../ui/KeyboardKey";

const shortcuts = [
  {
    keys: ["⌘", "⇧", "A"],
    label: "Open clipboard history",
    description: "Access your full clipboard from anywhere",
  },
  {
    keys: ["⌘", "⇧", "C"],
    label: "Copy to Paste Stack",
    description: "Add items for sequential pasting",
  },
  {
    keys: ["⌘", "⇧", "`"],
    label: "Screen OCR",
    description: "Extract text from any screen region",
  },
  {
    keys: ["⌘", "1-9"],
    label: "Quick select",
    description: "Instantly paste recent items by number",
  },
  {
    keys: ["Space"],
    label: "Preview",
    description: "Quick preview the selected item",
  },
  {
    keys: ["Hold Space"],
    label: "Edit",
    description: "Open the rich text editor",
  },
];

export function Shortcuts() {
  return (
    <section id="shortcuts" className="relative py-32">
      <div className="mx-auto max-w-[var(--container)] px-6">
        <div className="grid gap-16 lg:grid-cols-[1fr_1.1fr] items-center">
          {/* Left - Copy */}
          <FadeIn direction="right">
            <div>
              <p className="text-[13px] font-semibold uppercase tracking-widest text-orange-400/70 mb-4">
                Keyboard-first
              </p>
              <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
                Built for
                <br />
                <span className="gradient-text">your fingers</span>
              </h2>
              <p className="mt-5 text-base text-white/40 leading-relaxed max-w-md">
                Every feature in Superclip is accessible via keyboard. Navigate
                history, manage pinboards, paste from your stack &mdash; all
                without reaching for the mouse.
              </p>

              <div className="mt-8 flex items-center gap-3 text-[13px] text-white/30">
                <span>Try it:</span>
                <div className="flex gap-1">
                  <KeyboardKey glow>⌘</KeyboardKey>
                  <KeyboardKey glow>⇧</KeyboardKey>
                  <KeyboardKey glow>A</KeyboardKey>
                </div>
                <span>to open anywhere</span>
              </div>
            </div>
          </FadeIn>

          {/* Right - Shortcuts Grid */}
          <FadeIn direction="left" delay={0.15}>
            <div className="grid gap-3 sm:grid-cols-2">
              {shortcuts.map((shortcut) => (
                <div
                  key={shortcut.label}
                  className="glass glass-hover p-4 transition-all duration-200 group"
                >
                  <div className="flex flex-wrap gap-1 mb-3">
                    {shortcut.keys.map((key) => (
                      <KeyboardKey key={key}>{key}</KeyboardKey>
                    ))}
                  </div>
                  <p className="text-[13px] font-semibold text-white/80 mb-0.5">
                    {shortcut.label}
                  </p>
                  <p className="text-[12px] text-white/35">
                    {shortcut.description}
                  </p>
                </div>
              ))}
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
