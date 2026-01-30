interface KeyboardKeyProps {
  children: React.ReactNode;
  glow?: boolean;
}

export function KeyboardKey({ children, glow }: KeyboardKeyProps) {
  return (
    <kbd
      className={`
        inline-flex h-7 min-w-[28px] items-center justify-center rounded-md
        border border-white/[0.1] bg-white/[0.04] px-2
        font-mono text-[11px] font-medium text-white/60
        shadow-[0_1px_2px_rgba(0,0,0,0.3),inset_0_1px_0_rgba(255,255,255,0.05)]
        ${glow ? "border-cyan-500/30 text-cyan-400/80 shadow-[0_0_8px_rgba(0,212,255,0.15)]" : ""}
      `}
    >
      {children}
    </kbd>
  );
}
