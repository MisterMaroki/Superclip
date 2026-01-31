import type { Metadata } from 'next';
import Link from 'next/link';
import { getDocsByCategory } from '@/lib/docs';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Documentation',
	description:
		'Learn how to use Superclip — installation, features, keyboard shortcuts, privacy settings, and troubleshooting.',
	alternates: {
		canonical: 'https://superclip.app/docs',
	},
	openGraph: {
		title: 'Documentation | Superclip',
		description:
			'Learn how to use Superclip — installation, features, keyboard shortcuts, privacy settings, and troubleshooting.',
		url: 'https://superclip.app/docs',
		images: ['/og-image.png'],
	},
};

const categoryIcons: Record<string, string> = {
	'Getting Started': 'M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z',
	Features: 'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z',
	'Keyboard Shortcuts': 'M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z',
	'Privacy & Settings': 'M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z',
	Troubleshooting: 'M11.42 15.17l-5.672-5.671a8.267 8.267 0 011.176-3.076l.072-.11a8.252 8.252 0 012.576-2.576l.11-.072a8.267 8.267 0 013.076-1.176l.11-.014a8.252 8.252 0 013.676.504l.072.032a8.267 8.267 0 012.992 2.17l.076.09a8.252 8.252 0 011.47 3.274l.018.11a8.267 8.267 0 01-.504 3.676l-.032.072a8.252 8.252 0 01-2.17 2.992l-.09.076a8.267 8.267 0 01-3.274 1.47l-.11.018a8.252 8.252 0 01-3.676-.504l-.072-.032-.11-.053-5.672 5.671a2.25 2.25 0 01-3.182-3.182z',
};

export default function DocsPage() {
	const categories = getDocsByCategory();

	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<div className="mx-auto max-w-[var(--container)] px-6">
					{/* Heading */}
					<div className="mb-12 max-w-2xl">
						<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
							Documentation
						</h1>
						<p className="text-[15px] leading-relaxed text-white/45">
							Everything you need to know about using Superclip. From
							installation to advanced features.
						</p>
					</div>

					{/* Category Grid */}
					<div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
						{categories.map((cat) => {
							const iconPath = categoryIcons[cat.category];
							return (
								<div
									key={cat.category}
									className="group rounded-xl border border-white/[0.08] bg-white/[0.02] p-6 transition-colors duration-200 hover:bg-white/[0.04] hover:border-white/[0.12]"
								>
									{/* Category header */}
									<div className="mb-4 flex items-center gap-3">
										{iconPath && (
											<div className="flex h-9 w-9 items-center justify-center rounded-lg bg-white/[0.06] border border-white/[0.08]">
												<svg
													className="h-4.5 w-4.5 text-[var(--cyan)]"
													fill="none"
													viewBox="0 0 24 24"
													stroke="currentColor"
													strokeWidth={1.5}
												>
													<path
														strokeLinecap="round"
														strokeLinejoin="round"
														d={iconPath}
													/>
												</svg>
											</div>
										)}
										<h2 className="text-[16px] font-semibold text-white/90">
											{cat.category}
										</h2>
									</div>

									{/* Doc links */}
									<ul className="space-y-1.5">
										{cat.docs.map((doc) => (
											<li key={doc.slug}>
												<Link
													href={`/docs/${doc.slug}`}
													className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-[13px] text-white/50 hover:text-white/80 hover:bg-white/[0.04] transition-colors duration-150"
												>
													<svg
														className="h-3 w-3 shrink-0 text-white/20"
														fill="none"
														viewBox="0 0 24 24"
														stroke="currentColor"
														strokeWidth={2}
													>
														<path
															strokeLinecap="round"
															strokeLinejoin="round"
															d="M8.25 4.5l7.5 7.5-7.5 7.5"
														/>
													</svg>
													{doc.title}
												</Link>
											</li>
										))}
									</ul>
								</div>
							);
						})}
					</div>
				</div>
			</main>
			<Footer />
		</>
	);
}
