import Link from "next/link";
import type { Post } from "@/lib/blog";

interface BlogHeaderProps {
  post: Post;
}

export function BlogHeader({ post }: BlogHeaderProps) {
  return (
    <header className="mb-10">
      <Link
        href="/blog"
        className="mb-6 inline-flex items-center gap-1.5 text-[13px] text-white/40 hover:text-white/70 transition-colors duration-200"
      >
        <svg
          className="h-3.5 w-3.5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M15.75 19.5L8.25 12l7.5-7.5"
          />
        </svg>
        Back to Blog
      </Link>

      {/* Tags */}
      <div className="mb-4 flex flex-wrap gap-2">
        {post.tags.map((tag) => (
          <span
            key={tag}
            className="rounded-full bg-white/[0.06] border border-white/[0.08] px-2.5 py-0.5 text-[11px] font-medium text-white/40"
          >
            {tag}
          </span>
        ))}
      </div>

      {/* Title */}
      <h1 className="mb-4 text-3xl font-bold tracking-tight text-white sm:text-4xl">
        {post.title}
      </h1>

      {/* Description */}
      <p className="mb-6 text-[16px] leading-relaxed text-white/50">
        {post.description}
      </p>

      {/* Meta */}
      <div className="flex flex-wrap items-center gap-3 text-[13px] text-white/35">
        <span className="font-medium text-white/50">{post.author}</span>
        <span className="h-0.5 w-0.5 rounded-full bg-white/20" />
        <time dateTime={post.date}>
          {new Date(post.date).toLocaleDateString("en-US", {
            month: "long",
            day: "numeric",
            year: "numeric",
          })}
        </time>
        <span className="h-0.5 w-0.5 rounded-full bg-white/20" />
        <span>{post.readingTime}</span>
      </div>

      <hr className="mt-8 border-white/[0.08]" />
    </header>
  );
}
