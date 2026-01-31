import type { MDXComponents } from "mdx/types";

export const mdxComponents: MDXComponents = {
  h1: (props) => (
    <h1
      className="mt-12 mb-4 text-3xl font-bold tracking-tight text-white"
      {...props}
    />
  ),
  h2: (props) => (
    <h2
      className="mt-10 mb-4 text-2xl font-semibold tracking-tight text-white"
      {...props}
    />
  ),
  h3: (props) => (
    <h3
      className="mt-8 mb-3 text-xl font-semibold tracking-tight text-white"
      {...props}
    />
  ),
  h4: (props) => (
    <h4
      className="mt-6 mb-2 text-lg font-semibold text-white/90"
      {...props}
    />
  ),
  p: (props) => (
    <p className="mb-5 text-[15px] leading-relaxed text-white/60" {...props} />
  ),
  a: (props) => (
    <a
      className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors duration-200"
      target={props.href?.startsWith("http") ? "_blank" : undefined}
      rel={props.href?.startsWith("http") ? "noopener noreferrer" : undefined}
      {...props}
    />
  ),
  strong: (props) => (
    <strong className="font-semibold text-white/80" {...props} />
  ),
  em: (props) => <em className="italic text-white/50" {...props} />,
  code: (props) => (
    <code
      className="rounded-md bg-white/[0.06] border border-white/[0.08] px-1.5 py-0.5 text-[13px] font-mono text-[var(--cyan)]"
      {...props}
    />
  ),
  pre: (props) => (
    <pre
      className="my-6 overflow-x-auto rounded-xl border border-white/[0.08] bg-white/[0.03] p-4 text-[13px] leading-relaxed"
      {...props}
    />
  ),
  blockquote: (props) => (
    <blockquote
      className="my-6 border-l-2 border-[var(--cyan)]/40 pl-4 italic text-white/45"
      {...props}
    />
  ),
  ul: (props) => (
    <ul className="my-4 ml-4 list-disc space-y-2 text-white/50" {...props} />
  ),
  ol: (props) => (
    <ol
      className="my-4 ml-4 list-decimal space-y-2 text-white/50"
      {...props}
    />
  ),
  li: (props) => (
    <li className="text-[15px] leading-relaxed text-white/55" {...props} />
  ),
  table: (props) => (
    <div className="my-6 overflow-x-auto rounded-xl border border-white/[0.08]">
      <table className="w-full text-[14px]" {...props} />
    </div>
  ),
  thead: (props) => (
    <thead className="border-b border-white/[0.08] bg-white/[0.03]" {...props} />
  ),
  th: (props) => (
    <th
      className="px-4 py-3 text-left text-[13px] font-semibold text-white/70"
      {...props}
    />
  ),
  td: (props) => (
    <td
      className="border-t border-white/[0.06] px-4 py-3 text-white/50"
      {...props}
    />
  ),
  img: (props) => (
    <figure className="my-8">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        className="rounded-xl border border-white/[0.08] w-full"
        alt={props.alt ?? ""}
        {...props}
      />
      {props.alt && (
        <figcaption className="mt-2 text-center text-[12px] text-white/30">
          {props.alt}
        </figcaption>
      )}
    </figure>
  ),
  hr: () => <hr className="my-10 border-white/[0.08]" />,
};
