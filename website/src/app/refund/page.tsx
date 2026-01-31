import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Refund Policy',
	description:
		'Superclip refund policy. Not happy? Get a full refund within 30 days, no questions asked.',
	alternates: {
		canonical: 'https://superclip.app/refund',
	},
};

export default function RefundPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<article className="mx-auto max-w-2xl px-6">
					<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
						Refund Policy
					</h1>
					<p className="mb-8 text-[13px] text-white/35">
						Last updated: January 30, 2026
					</p>
					<hr className="mb-10 border-white/[0.08]" />

					<div className="space-y-8 text-[15px] leading-relaxed text-white/60">
						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								30-day money-back guarantee
							</h2>
							<p>
								If you&apos;re not happy with Superclip, you can request a full
								refund within 30 days of your purchase. No questions asked, no
								hoops to jump through.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								How to request a refund
							</h2>
							<p className="mb-3">
								Email{' '}
								<a
									href="mailto:hello@superclip.app"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									hello@superclip.app
								</a>{' '}
								with your purchase details. We&apos;ll process your refund
								within a few business days.
							</p>
							<p>
								If you purchased through the Mac App Store, you can also request
								a refund directly through{' '}
								<a
									href="https://reportaproblem.apple.com"
									target="_blank"
									rel="noopener noreferrer"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									Apple&apos;s Report a Problem
								</a>{' '}
								page.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Cancellations
							</h2>
							<p className="mb-3">
								You can cancel your subscription at any time. After cancellation:
							</p>
							<ul className="ml-4 list-disc space-y-1.5 text-white/55">
								<li>
									You keep access to Superclip until the end of your current
									billing period
								</li>
								<li>
									Your subscription won&apos;t renew
								</li>
								<li>
									No partial refunds are issued for unused time in the current
									period (but you can request a full refund within 30 days of
									the most recent charge)
								</li>
							</ul>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Free users
							</h2>
							<p>
								If you&apos;re one of the first 1,000 users with a free
								account, there&apos;s nothing to refund. Your access is free
								forever.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Questions?
							</h2>
							<p>
								Email{' '}
								<a
									href="mailto:hello@superclip.app"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									hello@superclip.app
								</a>{' '}
								if you have any questions about refunds or billing.
							</p>
						</section>
					</div>
				</article>
			</main>
			<Footer />
		</>
	);
}
