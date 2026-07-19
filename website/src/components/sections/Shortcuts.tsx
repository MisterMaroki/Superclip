"use client";

import { FadeIn } from "../effects/FadeIn";
import { KeyboardKey } from "../ui/KeyboardKey";

const shortcuts = [
  {
    keys: ["\u2318", "\u21E7", "A"],
    label: "Open clipboard history",
    description: "Access your full clipboard from anywhere",
  },
  {
    keys: ["\u2318", "\u21E7", "C"],
    label: "Copy to Paste Stack",
    description: "Add items for sequential pasting",
  },
  {
    keys: ["\u2318", "\u21E7", "`"],
    label: "Screen OCR",
    description: "Extract text from any screen region",
  },
  {
    keys: ["\u2318", "1-9"],
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
      <div className="mx-auto max-w-[var(--container)] px-10">
        <div className="grid gap-16 lg:grid-cols-[1fr_1.1fr] items-center">
          {/* Left - Copy */}
          <FadeIn direction="right">
            <div>
              <p className="section-label mb-4">Keyboard-first</p>
              <h2 style={{ fontSize: "clamp(32px, 5vw, 48px)" }}>
                Built for your fingers
              </h2>
              <p className="mt-5 text-base text-[var(--gray-500)] leading-relaxed max-w-md">
                Every feature in Superclip is accessible via keyboard. Navigate
                history, manage pinboards, paste from your stack &mdash; all
                without reaching for the mouse.
              </p>

              <div className="mt-8 flex items-center gap-3 text-[13px] text-[var(--gray-400)]">
                <span>Try it:</span>
                <div className="flex gap-1">
                  <KeyboardKey>{"\u2318"}</KeyboardKey>
                  <KeyboardKey>{"\u21E7"}</KeyboardKey>
                  <KeyboardKey>A</KeyboardKey>
                </div>
                <span>to open anywhere</span>
              </div>
            </div>
          </FadeIn>

          {/* Right - Shortcuts Grid */}
          <FadeIn direction="left" delay={0.1}>
            <div
              className="grid gap-px sm:grid-cols-2 border border-[var(--gray-200)]"
              style={{ background: "var(--gray-200)" }}
            >
              {shortcuts.map((shortcut) => (
                <div
                  key={shortcut.label}
                  className="bg-[var(--white)] p-4"
                >
                  <div className="flex flex-wrap gap-1 mb-3">
                    {shortcut.keys.map((key) => (
                      <KeyboardKey key={key}>{key}</KeyboardKey>
                    ))}
                  </div>
                  <p className="text-[13px] font-medium text-[var(--black)] mb-0.5">
                    {shortcut.label}
                  </p>
                  <p className="text-[12px] text-[var(--gray-400)]">
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
