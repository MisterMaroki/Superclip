import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MDXRemote } from 'next-mdx-remote/rsc';
import { getAllDocs, getDocBySlug, getDocsByCategory } from '@/lib/docs';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { DocsSidebar } from '@/components/docs/DocsSidebar';
import { DocsHeader } from '@/components/docs/DocsHeader';
import { mdxComponents } from '@/components/blog/MDXComponents';
import Link from 'next/link';

interface PageProps {
	params: Promise<{ slug: string }>;
}

export async function generateStaticParams() {
	const docs = getAllDocs();
	return docs.map((doc) => ({ slug: doc.slug }));
}

export async function generateMetadata({
	params,
}: PageProps): Promise<Metadata> {
	const { slug } = await params;
	let doc;
	try {
		doc = getDocBySlug(slug);
	} catch {
		return {};
	}

	return {
		title: doc.title,
		description: doc.description,
		alternates: {
			canonical: `https://superclip.app/docs/${doc.slug}`,
		},
		openGraph: {
			title: `${doc.title} | Superclip Docs`,
			description: doc.description,
			url: `https://superclip.app/docs/${doc.slug}`,
		},
	};
}

export default async function DocPage({ params }: PageProps) {
	const { slug } = await params;
	let doc;
	try {
		doc = getDocBySlug(slug);
	} catch {
		notFound();
	}

	const allDocs = getAllDocs();
	const categories = getDocsByCategory();

	const currentIndex = allDocs.findIndex((d) => d.slug === slug);
	const prevDoc = currentIndex > 0 ? allDocs[currentIndex - 1] : null;
	const nextDoc =
		currentIndex < allDocs.length - 1 ? allDocs[currentIndex + 1] : null;

	const sidebarCategories = categories.map((cat) => ({
		category: cat.category,
		docs: cat.docs.map((d) => ({ slug: d.slug, title: d.title })),
	}));

	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<div className="mx-auto max-w-[var(--container)] px-6">
					<div className="flex flex-col lg:flex-row gap-10">
						{/* Sidebar */}
						<DocsSidebar
							categories={sidebarCategories}
							currentSlug={slug}
						/>

						{/* Content */}
						<article className="min-w-0 flex-1 max-w-2xl">
							<DocsHeader
								title={doc.title}
								description={doc.description}
								category={doc.category}
							/>
							<MDXRemote
								source={doc.content}
								components={mdxComponents}
							/>

							{/* Prev/Next navigation */}
							<nav className="mt-16 flex items-stretch gap-4 border-t border-white/[0.08] pt-8">
								{prevDoc ? (
									<Link
										href={`/docs/${prevDoc.slug}`}
										className="group flex flex-1 flex-col rounded-xl border border-white/[0.08] bg-white/[0.02] p-4 transition-colors duration-200 hover:bg-white/[0.04] hover:border-white/[0.12]"
									>
										<span className="mb-1 text-[11px] font-medium uppercase tracking-wider text-white/30">
											Previous
										</span>
										<span className="text-[14px] font-medium text-white/60 group-hover:text-white/90 transition-colors">
											{prevDoc.title}
										</span>
									</Link>
								) : (
									<div className="flex-1" />
								)}
								{nextDoc ? (
									<Link
										href={`/docs/${nextDoc.slug}`}
										className="group flex flex-1 flex-col items-end rounded-xl border border-white/[0.08] bg-white/[0.02] p-4 text-right transition-colors duration-200 hover:bg-white/[0.04] hover:border-white/[0.12]"
									>
										<span className="mb-1 text-[11px] font-medium uppercase tracking-wider text-white/30">
											Next
										</span>
										<span className="text-[14px] font-medium text-white/60 group-hover:text-white/90 transition-colors">
											{nextDoc.title}
										</span>
									</Link>
								) : (
									<div className="flex-1" />
								)}
							</nav>
						</article>
					</div>
				</div>
			</main>
			<Footer />
		</>
	);
}
