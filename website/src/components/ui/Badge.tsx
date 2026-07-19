interface BadgeProps {
  children: React.ReactNode;
  variant?: "default" | "emphasis";
}

export function Badge({ children, variant = "default" }: BadgeProps) {
  const styles = {
    default: "border-[var(--gray-300)] text-[var(--gray-500)]",
    emphasis: "border-[var(--gray-700)] text-[var(--black)]",
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 border px-3.5 py-1.5 font-mono text-[11px] tracking-[0.025em] ${styles[variant]}`}
    >
      {children}
    </span>
  );
}
