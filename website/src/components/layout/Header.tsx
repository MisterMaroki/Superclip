'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const navLinks = [
	{ label: 'Home', href: '/' },
	{ label: 'Docs', href: '/docs' },
	{ label: 'Blog', href: '/blog' },
];

export function Header() {
	const [scrolled, setScrolled] = useState(false);
	const [mobileOpen, setMobileOpen] = useState(false);

	useEffect(() => {
		const onScroll = () => setScrolled(window.scrollY > 20);
		window.addEventListener('scroll', onScroll, { passive: true });
		return () => window.removeEventListener('scroll', onScroll);
	}, []);

	return (
		<header
			className="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
			style={{
				background: scrolled ? 'rgba(5, 5, 7, 0.82)' : 'rgba(5, 5, 7, 0)',
				backdropFilter: scrolled ? 'blur(20px) saturate(180%)' : 'none',
				borderBottom: scrolled
					? '1px solid rgba(255,255,255,0.06)'
					: '1px solid transparent',
			}}
		>
			<nav className="mx-auto flex h-16 max-w-[var(--container)] items-center justify-between px-6">
				{/* Logo */}
				<a href="/" className="flex items-center gap-2.5 group">
					<img
						src="/app-icon.png"
						alt="Superclip"
						className="h-8 w-8 transition-[filter] duration-200"
						style={{
							filter: 'drop-shadow(0 2px 6px rgba(0,212,255,0.2))',
						}}
					/>
					<span className="text-[15px] font-semibold tracking-tight text-white/90">
						Superclip
					</span>
				</a>

				{/* Desktop Nav */}
				<ul className="hidden md:flex items-center gap-8">
					{navLinks.map((link) => (
						<li key={link.href}>
							<a
								href={link.href}
								className="text-[13px] font-medium text-white/50 hover:text-white/90 transition-colors duration-200"
							>
								{link.label}
							</a>
						</li>
					))}
				</ul>

				{/* CTA */}
				<div className="hidden md:flex items-center gap-3">
					<a
						href="/#pricing"
						className="inline-flex h-9 items-center rounded-full bg-white/[0.08] px-4 text-[13px] font-medium text-white/80 hover:bg-white/[0.12] hover:text-white transition-all duration-200 border border-white/[0.06]"
					>
						Pricing
					</a>
					<a
						href="/#download"
						className="inline-flex h-9 items-center rounded-full px-4 text-[13px] font-semibold text-white transition-all duration-200 hover:brightness-110"
						style={{ background: 'var(--gradient-primary)' }}
					>
						Download
					</a>
				</div>

				{/* Mobile Toggle */}
				<button
					className="md:hidden flex flex-col gap-1.5 p-2"
					onClick={() => setMobileOpen(!mobileOpen)}
					aria-label="Toggle menu"
				>
					<span
						className={`block h-px w-5 bg-white/70 transition-transform duration-200 ${mobileOpen ? 'translate-y-[3.5px] rotate-45' : ''}`}
					/>
					<span
						className={`block h-px w-5 bg-white/70 transition-opacity duration-200 ${mobileOpen ? 'opacity-0' : ''}`}
					/>
					<span
						className={`block h-px w-5 bg-white/70 transition-transform duration-200 ${mobileOpen ? '-translate-y-[3.5px] -rotate-45' : ''}`}
					/>
				</button>
			</nav>

			{/* Mobile Menu */}
			<AnimatePresence>
				{mobileOpen && (
					<motion.div
						initial={{ opacity: 0, height: 0 }}
						animate={{ opacity: 1, height: 'auto' }}
						exit={{ opacity: 0, height: 0 }}
						className="md:hidden overflow-hidden border-t border-white/[0.06]"
						style={{ background: 'rgba(5, 5, 7, 0.95)' }}
					>
						<div className="flex flex-col gap-1 p-4">
							{navLinks.map((link) => (
								<a
									key={link.href}
									href={link.href}
									onClick={() => setMobileOpen(false)}
									className="rounded-lg px-4 py-2.5 text-[14px] text-white/70 hover:text-white hover:bg-white/[0.06] transition-colors"
								>
									{link.label}
								</a>
							))}
							<div className="mt-2 pt-2 border-t border-white/[0.06]">
								<a
									href="/#download"
									onClick={() => setMobileOpen(false)}
									className="flex items-center justify-center rounded-lg py-2.5 text-[14px] font-semibold text-white"
									style={{ background: 'var(--gradient-primary)' }}
								>
									Download Free
								</a>
							</div>
						</div>
					</motion.div>
				)}
			</AnimatePresence>
		</header>
	);
}
