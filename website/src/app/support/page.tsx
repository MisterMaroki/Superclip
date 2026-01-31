import type { Metadata } from 'next';
import Link from 'next/link';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Support',
	description:
		'Get help with Superclip. Browse the docs, troubleshoot common issues, or reach out directly.',
	alternates: {
		canonical: 'https://superclip.app/support',
	},
};

const resources = [
	{
		title: 'Documentation',
		description:
			'Guides for every feature — installation, clipboard history, paste stack, OCR, and more.',
		href: '/docs',
		icon: 'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25',
	},
	{
		title: 'Troubleshooting',
		description:
			'Fixes for permissions issues, hotkey conflicts, and other common problems.',
		href: '/docs/troubleshooting',
		icon: 'M11.42 15.17l-5.672-5.671a8.267 8.267 0 011.176-3.076l.072-.11a8.252 8.252 0 012.576-2.576l.11-.072a8.267 8.267 0 013.076-1.176l.11-.014a8.252 8.252 0 013.676.504l.072.032a8.267 8.267 0 012.992 2.17l.076.09a8.252 8.252 0 011.47 3.274l.018.11a8.267 8.267 0 01-.504 3.676l-.032.072a8.252 8.252 0 01-2.17 2.992l-.09.076a8.267 8.267 0 01-3.274 1.47l-.11.018a8.252 8.252 0 01-3.676-.504l-.072-.032-.11-.053-5.672 5.671a2.25 2.25 0 01-3.182-3.182z',
	},
	{
		title: 'Keyboard Shortcuts',
		description:
			'Full reference for all global hotkeys and in-app shortcuts.',
		href: '/docs/keyboard-shortcuts',
		icon: 'M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z',
	},
	{
		title: 'Quick Start',
		description:
			'New to Superclip? Get up and running in two minutes.',
		href: '/docs/quick-start',
		icon: 'M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z',
	},
];

export default function SupportPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<div className="mx-auto max-w-[var(--container)] px-6">
					{/* Heading */}
					<div className="mb-12 max-w-2xl">
						<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
							Support
						</h1>
						<p className="text-[15px] leading-relaxed text-white/45">
							Need help with Superclip? Start with the resources below, or
							reach out directly.
						</p>
					</div>

					{/* Resource cards */}
					<div className="mb-16 grid gap-5 sm:grid-cols-2">
						{resources.map((r) => (
							<Link
								key={r.href}
								href={r.href}
								className="group flex gap-4 rounded-xl border border-white/[0.08] bg-white/[0.02] p-5 transition-colors duration-200 hover:bg-white/[0.04] hover:border-white/[0.12]"
							>
								<div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-white/[0.06] border border-white/[0.08]">
									<svg
										className="h-5 w-5 text-[var(--cyan)]"
										fill="none"
										viewBox="0 0 24 24"
										stroke="currentColor"
										strokeWidth={1.5}
									>
										<path
											strokeLinecap="round"
											strokeLinejoin="round"
											d={r.icon}
										/>
									</svg>
								</div>
								<div>
									<h2 className="mb-1 text-[15px] font-semibold text-white/90 group-hover:text-white transition-colors">
										{r.title}
									</h2>
									<p className="text-[13px] leading-relaxed text-white/45">
										{r.description}
									</p>
								</div>
							</Link>
						))}
					</div>

					{/* Contact section */}
					<div className="mx-auto max-w-2xl rounded-xl border border-white/[0.08] bg-white/[0.02] p-8">
						<h2 className="mb-2 text-xl font-semibold text-white">
							Still need help?
						</h2>
						<p className="mb-6 text-[15px] leading-relaxed text-white/50">
							If the docs don&apos;t cover your issue, send an email and
							I&apos;ll get back to you as soon as I can.
						</p>
						<a
							href="mailto:support@superclip.app"
							className="inline-flex h-10 items-center rounded-full px-5 text-[13px] font-semibold text-white transition-all duration-200 hover:brightness-110"
							style={{ background: 'var(--gradient-primary)' }}
						>
							Email support@superclip.app
						</a>
					</div>
				</div>
			</main>
			<Footer />
		</>
	);
}
