import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Terms of Service',
	description:
		'Terms of Service for Superclip, the native macOS clipboard manager.',
	alternates: {
		canonical: 'https://superclip.app/terms',
	},
};

export default function TermsPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<article className="mx-auto max-w-2xl px-6">
					<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
						Terms of Service
					</h1>
					<p className="mb-8 text-[13px] text-white/35">
						Last updated: January 30, 2026
					</p>
					<hr className="mb-10 border-white/[0.08]" />

					<div className="space-y-8 text-[15px] leading-relaxed text-white/60">
						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Agreement
							</h2>
							<p>
								By downloading, installing, or using Superclip
								(&ldquo;the App&rdquo;), you agree to these Terms of Service.
								If you don&apos;t agree, don&apos;t use the App. These terms
								apply to all users of Superclip.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								What Superclip does
							</h2>
							<p>
								Superclip is a macOS clipboard manager that provides clipboard
								history, pinboards, paste stack, OCR, and screen capture
								features. It runs locally on your Mac. All data processing
								happens on your device.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								License
							</h2>
							<p className="mb-3">
								We grant you a limited, non-exclusive, non-transferable,
								revocable license to use Superclip on macOS devices you own or
								control, subject to these terms.
							</p>
							<p>You may not:</p>
							<ul className="mt-3 ml-4 list-disc space-y-1.5 text-white/55">
								<li>Reverse engineer, decompile, or disassemble the App</li>
								<li>
									Redistribute, sublicense, or resell the App or your license
								</li>
								<li>
									Use the App in any way that violates applicable laws
								</li>
								<li>
									Remove or alter any proprietary notices in the App
								</li>
							</ul>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Pricing and payment
							</h2>
							<p className="mb-3">
								Superclip is free for the first 1,000 users — permanently, with
								no restrictions. After those spots are claimed, Superclip is
								available as a paid subscription at the prices listed on our
								website.
							</p>
							<p className="mb-3">
								Payments are processed through the Mac App Store or Stripe. We
								do not store your payment information directly. Prices may
								change, but changes won&apos;t affect your current billing
								period.
							</p>
							<p>
								See our{' '}
								<a
									href="/refund"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									Refund Policy
								</a>{' '}
								for details on cancellations and refunds.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Free tier
							</h2>
							<p>
								Users who claimed a free spot retain access to Superclip at no
								cost for as long as the App exists. Free accounts have full
								access to all features — there are no feature restrictions or
								hidden limitations. We reserve the right to modify features
								available in the free tier for new signups, but existing free
								users will not lose access to features they had when they signed
								up.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Your data
							</h2>
							<p>
								Superclip processes clipboard data locally on your Mac. We
								don&apos;t have access to your clipboard contents, history, or
								pinned items. You are responsible for any data you copy and how
								you use the App. See our{' '}
								<a
									href="/privacy"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									Privacy Policy
								</a>{' '}
								for full details.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Accessibility permissions
							</h2>
							<p>
								Superclip requires macOS Accessibility permissions to function.
								This is used solely for registering global keyboard shortcuts
								and simulating paste actions. The App does not use these
								permissions to read content from other applications beyond
								standard clipboard access.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Disclaimers
							</h2>
							<p className="mb-3">
								Superclip is provided &ldquo;as is&rdquo; without warranties of
								any kind, express or implied. We don&apos;t guarantee that the
								App will be uninterrupted, error-free, or compatible with all
								macOS configurations.
							</p>
							<p>
								We are not responsible for data loss resulting from use of the
								App, including clipboard items that are not captured or are
								accidentally deleted.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Limitation of liability
							</h2>
							<p>
								To the maximum extent permitted by law, Superclip and its
								creator shall not be liable for any indirect, incidental,
								special, consequential, or punitive damages arising from your
								use of the App. Our total liability is limited to the amount you
								paid for Superclip in the 12 months preceding the claim.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Termination
							</h2>
							<p>
								You can stop using Superclip at any time by uninstalling it. We
								may terminate or suspend your license if you violate these
								terms. On termination, your right to use the App ends, but
								provisions regarding liability and disclaimers survive.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Changes to these terms
							</h2>
							<p>
								We may update these terms from time to time. Changes take effect
								when posted on this page. Continued use of the App after changes
								are posted constitutes acceptance of the new terms.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Contact
							</h2>
							<p>
								Questions about these terms? Email{' '}
								<a
									href="mailto:hello@superclip.app"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									hello@superclip.app
								</a>
								.
							</p>
						</section>
					</div>
				</article>
			</main>
			<Footer />
		</>
	);
}
