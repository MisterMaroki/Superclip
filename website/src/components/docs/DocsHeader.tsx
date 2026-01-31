import Link from 'next/link';

interface DocsHeaderProps {
	title: string;
	description: string;
	category: string;
}

export function DocsHeader({ title, description, category }: DocsHeaderProps) {
	return (
		<header className="mb-10">
			{/* Breadcrumb */}
			<nav className="mb-6 flex items-center gap-1.5 text-[13px] text-white/40">
				<Link
					href="/docs"
					className="hover:text-white/70 transition-colors duration-200"
				>
					Docs
				</Link>
				<svg
					className="h-3 w-3 text-white/20"
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
				<span>{category}</span>
				<svg
					className="h-3 w-3 text-white/20"
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
				<span className="text-white/60">{title}</span>
			</nav>

			{/* Title */}
			<h1 className="mb-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
				{title}
			</h1>

			{/* Description */}
			<p className="text-[16px] leading-relaxed text-white/50">
				{description}
			</p>

			<hr className="mt-8 border-white/[0.08]" />
		</header>
	);
}
