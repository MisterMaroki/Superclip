export function Footer() {
  const columns = [
    {
      title: "Product",
      links: [
        { label: "Features", href: "/#features" },
        { label: "Pricing", href: "/#pricing" },
        { label: "Download", href: "/#download" },
        { label: "Blog", href: "/blog" },
        { label: "Changelog", href: "/changelog" },
      ],
    },
    {
      title: "Resources",
      links: [
        { label: "Documentation", href: "/docs" },
        { label: "Keyboard Shortcuts", href: "/#shortcuts" },
        { label: "Support", href: "/support" },
        { label: "Contact", href: "/contact" },
      ],
    },
    {
      title: "Legal",
      links: [
        { label: "Privacy Policy", href: "/privacy" },
        { label: "Terms of Service", href: "/terms" },
        { label: "Refund Policy", href: "/refund" },
      ],
    },
  ];

  return (
    <footer className="border-t border-[var(--gray-200)]">
      <div className="mx-auto max-w-[var(--container)] px-10 py-16">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2.5 mb-4">
              <svg className="h-7 w-7" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
                <rect width="512" height="512" fill="var(--black)"/>
                <rect x="48" y="232" width="416" height="232" fill="var(--white)"/>
                <rect x="96" y="276" width="224" height="20" fill="var(--black)"/>
                <rect x="96" y="324" width="320" height="20" fill="var(--black)" opacity="0.45"/>
                <rect x="96" y="372" width="176" height="20" fill="var(--black)" opacity="0.15"/>
              </svg>
              <span className="font-mono text-[13px] uppercase tracking-[0.1em] text-[var(--black)]">
                Superclip
              </span>
            </div>
            <p className="text-[14px] leading-relaxed text-[var(--gray-600)] max-w-[240px]">
              The clipboard manager macOS deserves. Faster, smarter, and half
              the price.
            </p>
          </div>

          {/* Link Columns */}
          {columns.map((col) => (
            <div key={col.title}>
              <h4 className="not-italic font-mono text-[11px] font-normal uppercase tracking-[0.1em] text-[var(--gray-500)] mb-4">
                {col.title}
              </h4>
              <ul className="space-y-2.5">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      className="text-[14px] text-[var(--gray-500)] hover:text-[var(--black)] transition-colors duration-150"
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
        <div className="mt-16 pt-6 border-t border-[var(--gray-200)] flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="font-mono text-[11px] tracking-[0.025em] text-[var(--gray-400)]">
            Omar Maroki &middot; est. 2025 &middot; Superclip
          </p>
          <p className="font-mono text-[11px] tracking-[0.025em] text-[var(--gray-400)]">
            &copy; {new Date().getFullYear()} Superclip. Made for macOS.
          </p>
        </div>
      </div>
    </footer>
  );
}
