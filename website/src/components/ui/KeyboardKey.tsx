interface KeyboardKeyProps {
  children: React.ReactNode;
  glow?: boolean;
}

export function KeyboardKey({ children }: KeyboardKeyProps) {
  return (
    <kbd className="inline-flex h-7 min-w-[28px] items-center justify-center border border-[var(--gray-200)] bg-[var(--gray-100)] px-2 font-mono text-[11px] text-[var(--gray-600)]">
      {children}
    </kbd>
  );
}
