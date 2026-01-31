import type { Metadata } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
	title: 'Contact',
	description: 'Get in touch with the Superclip team.',
	alternates: {
		canonical: 'https://superclip.app/contact',
	},
};

const channels = [
	{
		label: 'General',
		email: 'hello@superclip.app',
		description: 'Questions, feedback, or just saying hi.',
	},
	{
		label: 'Support',
		email: 'support@superclip.app',
		description: 'Bug reports, technical issues, or feature requests.',
	},
	{
		label: 'Privacy',
		email: 'privacy@superclip.app',
		description: 'Questions about data handling or our privacy policy.',
	},
];

export default function ContactPage() {
	return (
		<>
			<Header />
			<main className="min-h-screen pt-32 pb-20">
				<div className="mx-auto max-w-2xl px-6">
					{/* Heading */}
					<div className="mb-12">
						<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
							Contact
						</h1>
						<p className="text-[15px] leading-relaxed text-white/45">
							Superclip is built by one person. I read every email and try to
							respond within a day.
						</p>
					</div>

					{/* Email channels */}
					<div className="space-y-4">
						{channels.map((ch) => (
							<div
								key={ch.email}
								className="rounded-xl border border-white/[0.08] bg-white/[0.02] p-5"
							>
								<div className="mb-1 flex items-baseline gap-3">
									<span className="text-[12px] font-semibold uppercase tracking-wider text-white/30">
										{ch.label}
									</span>
								</div>
								<a
									href={`mailto:${ch.email}`}
									className="mb-1.5 block text-[15px] font-medium text-[var(--cyan)] underline decoration-[var(--cyan)]/30 underline-offset-2 hover:decoration-[var(--cyan)] transition-colors"
								>
									{ch.email}
								</a>
								<p className="text-[13px] text-white/45">{ch.description}</p>
							</div>
						))}
					</div>

					{/* Note */}
					<p className="mt-10 text-[13px] leading-relaxed text-white/35">
						For account or billing issues, include the email address you used
						to purchase. For bugs, include your macOS version and what you were
						doing when the issue occurred.
					</p>
				</div>
			</main>
			<Footer />
		</>
	);
}
