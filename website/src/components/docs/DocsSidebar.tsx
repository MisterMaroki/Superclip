'use client';

import { useState } from 'react';
import Link from 'next/link';

interface SidebarDoc {
	slug: string;
	title: string;
}

interface SidebarCategory {
	category: string;
	docs: SidebarDoc[];
}

interface DocsSidebarProps {
	categories: SidebarCategory[];
	currentSlug: string;
}

export function DocsSidebar({ categories, currentSlug }: DocsSidebarProps) {
	const [mobileOpen, setMobileOpen] = useState(false);

	return (
		<>
			{/* Mobile toggle */}
			<button
				onClick={() => setMobileOpen(!mobileOpen)}
				className="flex items-center gap-2 rounded-lg border border-white/[0.08] bg-white/[0.04] px-3 py-2 text-[13px] text-white/60 hover:bg-white/[0.06] transition-colors lg:hidden"
				aria-label="Toggle docs navigation"
			>
				<svg
					className={`h-4 w-4 transition-transform duration-200 ${mobileOpen ? 'rotate-90' : ''}`}
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
					strokeWidth={2}
				>
					<path
						strokeLinecap="round"
						strokeLinejoin="round"
						d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
					/>
				</svg>
				Navigation
			</button>

			{/* Sidebar */}
			<nav
				className={`${
					mobileOpen ? 'block' : 'hidden'
				} lg:block w-full lg:w-56 shrink-0`}
			>
				<div className="lg:sticky lg:top-24 lg:max-h-[calc(100vh-7rem)] lg:overflow-y-auto rounded-xl border border-white/[0.08] bg-white/[0.02] p-4 backdrop-blur-sm">
					{categories.map((cat) => (
						<div key={cat.category} className="mb-5 last:mb-0">
							<h4 className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-white/30">
								{cat.category}
							</h4>
							<ul className="space-y-0.5">
								{cat.docs.map((doc) => {
									const isActive = doc.slug === currentSlug;
									return (
										<li key={doc.slug}>
											<Link
												href={`/docs/${doc.slug}`}
												onClick={() => setMobileOpen(false)}
												className={`block rounded-lg px-3 py-1.5 text-[13px] transition-colors duration-150 ${
													isActive
														? 'bg-white/[0.08] text-white font-medium'
														: 'text-white/50 hover:text-white/80 hover:bg-white/[0.04]'
												}`}
											>
												{doc.title}
											</Link>
										</li>
									);
								})}
							</ul>
						</div>
					))}
				</div>
			</nav>
		</>
	);
}
