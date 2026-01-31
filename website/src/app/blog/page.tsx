import type { Metadata } from "next";
import { getAllPosts } from "@/lib/blog";
import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";
import { PostCard } from "@/components/blog/PostCard";

export const metadata: Metadata = {
  title: "Blog",
  description:
    "Tips, comparisons, and updates from the Superclip team. Learn how to get the most out of your clipboard on macOS.",
  alternates: {
    canonical: "https://superclip.app/blog",
  },
  openGraph: {
    title: "Blog | Superclip",
    description:
      "Tips, comparisons, and updates from the Superclip team. Learn how to get the most out of your clipboard on macOS.",
    url: "https://superclip.app/blog",
  },
};

export default function BlogPage() {
  const posts = getAllPosts();

  return (
    <>
      <Header />
      <main className="min-h-screen pt-32 pb-20">
        <div className="mx-auto max-w-[var(--container)] px-6">
          {/* Heading */}
          <div className="mb-12 max-w-2xl">
            <h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              Blog
            </h1>
            <p className="text-[15px] leading-relaxed text-white/45">
              Tips, comparisons, and updates from the Superclip team.
            </p>
          </div>

          {/* Post Grid */}
          <div className="grid gap-6 sm:grid-cols-2">
            {posts.map((post, i) => (
              <PostCard key={post.slug} post={post} index={i} />
            ))}
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
