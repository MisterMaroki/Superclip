interface BadgeProps {
  children: React.ReactNode;
  variant?: "default" | "gradient" | "success";
}

export function Badge({ children, variant = "default" }: BadgeProps) {
  const styles = {
    default:
      "bg-white/[0.06] border-white/[0.08] text-white/70",
    gradient:
      "bg-gradient-to-r from-cyan-500/10 to-purple-500/10 border-cyan-500/20 text-cyan-300",
    success:
      "bg-emerald-500/10 border-emerald-500/20 text-emerald-400",
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[12px] font-medium tracking-wide ${styles[variant]}`}
    >
      {children}
    </span>
  );
}
