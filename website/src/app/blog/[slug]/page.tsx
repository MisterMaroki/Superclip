import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { MDXRemote } from "next-mdx-remote/rsc";
import { getAllPosts, getPostBySlug } from "@/lib/blog";
import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";
import { BlogHeader } from "@/components/blog/BlogHeader";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { InlineCTA } from "@/components/ui/InlineCTA";

interface PageProps {
  params: Promise<{ slug: string }>;
}

export async function generateStaticParams() {
  const posts = getAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({
  params,
}: PageProps): Promise<Metadata> {
  const { slug } = await params;
  let post;
  try {
    post = getPostBySlug(slug);
  } catch {
    return {};
  }

  return {
    title: post.title,
    description: post.description,
    alternates: {
      canonical: `https://superclip.app/blog/${post.slug}`,
    },
    openGraph: {
      title: post.title,
      description: post.description,
      type: "article",
      publishedTime: post.date,
      url: `https://superclip.app/blog/${post.slug}`,
      authors: [post.author],
      images: ["/og-image.png"],
    },
    twitter: {
      card: "summary_large_image",
      title: post.title,
      description: post.description,
      images: ["/og-image.png"],
    },
  };
}

function ArticleJsonLd({ post }: { post: ReturnType<typeof getPostBySlug> }) {
  const schema = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: post.title,
    description: post.description,
    datePublished: post.date,
    author: {
      "@type": "Person",
      name: post.author,
    },
    publisher: {
      "@type": "Organization",
      name: "Superclip",
      url: "https://superclip.app",
    },
    mainEntityOfPage: `https://superclip.app/blog/${post.slug}`,
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}

export default async function BlogPostPage({ params }: PageProps) {
  const { slug } = await params;
  let post;
  try {
    post = getPostBySlug(slug);
  } catch {
    notFound();
  }

  return (
    <>
      <ArticleJsonLd post={post} />
      <Header />
      <main className="min-h-screen pt-32 pb-20">
        <article className="mx-auto max-w-2xl px-6">
          <BlogHeader post={post} />
          <MDXRemote source={post.content} components={mdxComponents} />
          <InlineCTA
            text="Try the clipboard manager macOS deserves."
            href="/#download"
          />
        </article>
      </main>
      <Footer />
    </>
  );
}
