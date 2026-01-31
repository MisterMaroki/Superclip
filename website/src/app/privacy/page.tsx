import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Privacy Policy',
	description:
		'Superclip privacy policy. Your clipboard data stays on your Mac — no cloud, no analytics, no tracking.',
	alternates: {
		canonical: 'https://superclip.app/privacy',
	},
};

export default function PrivacyPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<article className="mx-auto max-w-2xl px-6">
					<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
						Privacy Policy
					</h1>
					<p className="mb-8 text-[13px] text-white/35">
						Last updated: January 30, 2026
					</p>
					<hr className="mb-10 border-white/[0.08]" />

					<div className="space-y-8 text-[15px] leading-relaxed text-white/60">
						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								The short version
							</h2>
							<p>
								Superclip does not collect, transmit, or store any of your data
								outside of your Mac. Your clipboard history, pinned items, and
								settings stay on your device. There is no cloud sync, no
								analytics, no tracking, and no account required.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Data we collect
							</h2>
							<p className="mb-3">
								<strong className="text-white/80">None.</strong> Superclip does
								not collect any personal information, usage data, or telemetry.
								The app does not communicate with any server.
							</p>
							<p>
								Specifically, we do not collect:
							</p>
							<ul className="mt-3 ml-4 list-disc space-y-1.5 text-white/55">
								<li>Clipboard contents</li>
								<li>Usage analytics or behavior tracking</li>
								<li>Crash reports (unless you explicitly choose to send them)</li>
								<li>Device identifiers or fingerprints</li>
								<li>IP addresses</li>
								<li>Personal information of any kind</li>
							</ul>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Clipboard data
							</h2>
							<p className="mb-3">
								Superclip reads your system clipboard to provide clipboard
								history functionality. All clipboard data is stored in memory
								while the app is running and is never written to disk except for
								pinned items, which are saved locally on your Mac.
							</p>
							<p>
								If you enable &ldquo;Clear history on quit,&rdquo; all
								non-pinned clipboard data is erased when you close the app. You
								can also exclude specific apps from clipboard monitoring in
								Settings.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								OCR processing
							</h2>
							<p>
								Text extraction from images is performed entirely on your Mac
								using Apple&apos;s Vision framework. No images or extracted text
								are sent to any external service.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Third-party services
							</h2>
							<p className="mb-3">
								Superclip does not integrate with any third-party analytics,
								advertising, or tracking services.
							</p>
							<p>
								When you copy a URL, Superclip may fetch the page title and
								favicon to display link previews. These are standard HTTP
								requests to the URL you copied — no data about you or your
								usage is sent.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Payment processing
							</h2>
							<p>
								Payments are handled entirely through the Mac App Store or
								Stripe. We do not have access to your credit card number or
								payment details. See{' '}
								<a
									href="https://www.apple.com/legal/privacy/"
									target="_blank"
									rel="noopener noreferrer"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									Apple&apos;s Privacy Policy
								</a>{' '}
								or{' '}
								<a
									href="https://stripe.com/privacy"
									target="_blank"
									rel="noopener noreferrer"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									Stripe&apos;s Privacy Policy
								</a>{' '}
								for details on how they handle payment data.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Data storage and security
							</h2>
							<p>
								All data remains on your Mac. Clipboard history is held in
								memory. Pinned items and preferences are stored in your local
								Application Support directory. No data is transmitted over the
								network, backed up to the cloud, or accessible to us.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Children&apos;s privacy
							</h2>
							<p>
								Superclip does not collect any information from anyone,
								including children under the age of 13.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Changes to this policy
							</h2>
							<p>
								If we make changes to this privacy policy, we&apos;ll update
								this page and the &ldquo;last updated&rdquo; date above. Since
								we don&apos;t collect your email or any contact information, we
								can&apos;t notify you directly — check back here if you have
								concerns.
							</p>
						</section>

						<section>
							<h2 className="mb-3 text-xl font-semibold text-white">
								Contact
							</h2>
							<p>
								If you have questions about this privacy policy, reach out at{' '}
								<a
									href="mailto:privacy@superclip.app"
									className="text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									privacy@superclip.app
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
