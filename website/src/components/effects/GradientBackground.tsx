"use client";

export function GradientBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {/* Large cyan blob - top right */}
      <div
        className="absolute -top-[30%] -right-[10%] h-[700px] w-[700px] rounded-full opacity-[0.07] animate-gradient-rotate"
        style={{
          background:
            "radial-gradient(circle, var(--cyan) 0%, transparent 70%)",
        }}
      />
      {/* Purple blob - bottom left */}
      <div
        className="absolute -bottom-[20%] -left-[15%] h-[600px] w-[600px] rounded-full opacity-[0.06]"
        style={{
          background:
            "radial-gradient(circle, var(--purple) 0%, transparent 70%)",
          animation: "gradient-rotate 25s linear infinite reverse",
        }}
      />
      {/* Subtle center glow */}
      <div
        className="absolute top-[15%] left-1/2 -translate-x-1/2 h-[400px] w-[800px] rounded-full opacity-[0.04]"
        style={{
          background:
            "radial-gradient(ellipse, var(--cyan) 0%, transparent 70%)",
        }}
      />
      {/* Grid lines */}
      <div
        className="absolute inset-0 opacity-[0.015]"
        style={{
          backgroundImage: `linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px),
            linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)`,
          backgroundSize: "80px 80px",
        }}
      />
    </div>
  );
}
