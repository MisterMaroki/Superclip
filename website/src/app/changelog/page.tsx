import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Changelog',
	description:
		'What\u2019s new in Superclip. Release notes and version history.',
	alternates: {
		canonical: 'https://superclip.app/changelog',
	},
};

interface Release {
	version: string;
	date: string;
	tag?: string;
	changes: string[];
}

const releases: Release[] = [
	{
		version: '1.0.0',
		date: 'January 30, 2026',
		tag: 'Latest',
		changes: [
			'Initial release of Superclip',
			'Clipboard history with up to 100 items, deduplication, and source app tracking',
			'Full-text search across clipboard history',
			'Smart pinboards — pin, organize, and persist your favorite clips',
			'Paste stack — copy multiple items with Cmd+Shift+C, paste in sequence with Cmd+V',
			'Built-in OCR powered by Apple Vision framework',
			'Rich text editor for editing clipboard content',
			'Keyboard-first navigation with global hotkeys',
			'Privacy controls: app exclusions, auto-clear on quit',
			'Onboarding flow for first-time users',
			'Settings panel with macOS-style sidebar layout',
			'Native SwiftUI — no Electron, under 30MB memory usage',
		],
	},
];

export default function ChangelogPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<div className="mx-auto max-w-2xl px-6">
					{/* Heading */}
					<div className="mb-12">
						<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
							Changelog
						</h1>
						<p className="text-[15px] leading-relaxed text-white/45">
							Release notes and version history for Superclip.
						</p>
					</div>

					{/* Releases */}
					<div className="space-y-12">
						{releases.map((release) => (
							<article
								key={release.version}
								className="relative border-l-2 border-white/[0.08] pl-8"
							>
								{/* Timeline dot */}
								<div className="absolute -left-[5px] top-1 h-2 w-2 rounded-full bg-[var(--cyan)]" />

								{/* Header */}
								<div className="mb-4 flex flex-wrap items-baseline gap-3">
									<h2 className="text-xl font-semibold text-white">
										v{release.version}
									</h2>
									{release.tag && (
										<span className="rounded-full bg-[var(--cyan)]/10 border border-[var(--cyan)]/20 px-2.5 py-0.5 text-[11px] font-medium text-[var(--cyan)]">
											{release.tag}
										</span>
									)}
									<span className="text-[13px] text-white/35">
										{release.date}
									</span>
								</div>

								{/* Changes */}
								<ul className="space-y-2">
									{release.changes.map((change, i) => (
										<li
											key={i}
											className="flex gap-2.5 text-[14px] leading-relaxed text-white/55"
										>
											<span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-white/25" />
											{change}
										</li>
									))}
								</ul>
							</article>
						))}
					</div>
				</div>
			</main>
			<Footer />
		</>
	);
}
