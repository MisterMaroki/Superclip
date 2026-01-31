"use client";

import Link from "next/link";
import { FadeIn } from "../effects/FadeIn";
import type { Post } from "@/lib/blog";

interface PostCardProps {
  post: Post;
  index: number;
}

export function PostCard({ post, index }: PostCardProps) {
  return (
    <FadeIn delay={index * 0.08}>
      <Link href={`/blog/${post.slug}`} className="group block h-full">
        <article className="glass glass-hover h-full p-6 transition-all duration-300 hover:translate-y-[-2px]">
          {/* Tags */}
          <div className="mb-3 flex flex-wrap gap-2">
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
          <h2 className="mb-2 text-lg font-semibold tracking-tight text-white/90 group-hover:text-white transition-colors duration-200">
            {post.title}
          </h2>

          {/* Description */}
          <p className="mb-4 text-[14px] leading-relaxed text-white/45 line-clamp-2">
            {post.description}
          </p>

          {/* Meta */}
          <div className="flex items-center gap-3 text-[12px] text-white/30">
            <time dateTime={post.date}>
              {new Date(post.date).toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
                year: "numeric",
              })}
            </time>
            <span className="h-0.5 w-0.5 rounded-full bg-white/20" />
            <span>{post.readingTime}</span>
          </div>
        </article>
      </Link>
    </FadeIn>
  );
}
