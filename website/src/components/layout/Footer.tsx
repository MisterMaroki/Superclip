export function Footer() {
  const columns = [
    {
      title: "Product",
      links: [
        { label: "Features", href: "#features" },
        { label: "Pricing", href: "#pricing" },
        { label: "Download", href: "#download" },
        { label: "Changelog", href: "#" },
      ],
    },
    {
      title: "Resources",
      links: [
        { label: "Documentation", href: "#" },
        { label: "Keyboard Shortcuts", href: "#shortcuts" },
        { label: "Support", href: "#" },
        { label: "Contact", href: "#" },
      ],
    },
    {
      title: "Legal",
      links: [
        { label: "Privacy Policy", href: "#" },
        { label: "Terms of Service", href: "#" },
        { label: "Refund Policy", href: "#" },
      ],
    },
  ];

  return (
    <footer className="border-t border-white/[0.06] bg-[var(--bg)]">
      <div className="mx-auto max-w-[var(--container)] px-6 py-16">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2.5 mb-4">
              <img
                src="/app-icon.jpeg"
                alt="Superclip"
                className="h-8 w-8 rounded-lg"
              />
              <span className="text-[15px] font-semibold text-white/90">
                Superclip
              </span>
            </div>
            <p className="text-[13px] leading-relaxed text-white/40 max-w-[240px]">
              The clipboard manager macOS deserves. Faster, smarter, and half
              the price.
            </p>
          </div>

          {/* Link Columns */}
          {columns.map((col) => (
            <div key={col.title}>
              <h4 className="text-[12px] font-semibold uppercase tracking-wider text-white/30 mb-4">
                {col.title}
              </h4>
              <ul className="space-y-2.5">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      className="text-[13px] text-white/45 hover:text-white/80 transition-colors duration-200"
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom Bar */}
        <div className="mt-16 pt-6 border-t border-white/[0.06] flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-[12px] text-white/25">
            &copy; {new Date().getFullYear()} Superclip. Made for macOS.
          </p>
          <div className="flex items-center gap-1.5">
            <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400/80" />
            <span className="text-[12px] text-white/30">
              All systems operational
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}
