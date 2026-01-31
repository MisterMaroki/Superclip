import type { Metadata } from "next";

export const metadata: Metadata = {
	title: "OG Image Preview",
	robots: "noindex",
};

/* ─── Pixel art: Organized Pasteboard ─── */
function PasteboardArt() {
	// 8x6 grid representing organized clipboard items
	// 0 = empty, 1 = cyan, 2 = purple, 3 = emerald, 4 = pink, 5 = amber, 6 = dim
	const grid = [
		[1, 1, 1, 1, 6, 2, 2, 2],
		[1, 1, 1, 1, 6, 2, 2, 2],
		[6, 6, 6, 6, 6, 6, 6, 6],
		[3, 3, 3, 6, 4, 4, 4, 4],
		[3, 3, 3, 6, 4, 4, 4, 4],
		[6, 6, 6, 6, 6, 6, 6, 6],
		[5, 5, 5, 5, 5, 6, 1, 1],
		[5, 5, 5, 5, 5, 6, 1, 1],
	];

	const colors: Record<number, string> = {
		0: "transparent",
		1: "rgba(0, 212, 255, 0.7)",
		2: "rgba(139, 92, 246, 0.7)",
		3: "rgba(16, 185, 129, 0.6)",
		4: "rgba(236, 72, 153, 0.55)",
		5: "rgba(245, 158, 11, 0.55)",
		6: "rgba(255, 255, 255, 0.04)",
	};

	return (
		<div className="flex flex-col gap-[3px]">
			{grid.map((row, ri) => (
				<div key={ri} className="flex gap-[3px]">
					{row.map((cell, ci) => (
						<div
							key={ci}
							style={{
								width: 18,
								height: 14,
								borderRadius: 3,
								background: colors[cell],
								boxShadow:
									cell > 0 && cell < 6
										? `0 0 8px ${colors[cell]}`
										: "none",
							}}
						/>
					))}
				</div>
			))}
		</div>
	);
}

/* ─── Pixel art: Screen text capture / OCR ─── */
function CaptureArt() {
	// Simulated screen with text lines being scanned
	const lines = [
		{ w: "100%", scanned: false },
		{ w: "85%", scanned: false },
		{ w: "92%", scanned: true },
		{ w: "78%", scanned: true },
		{ w: "96%", scanned: true },
		{ w: "60%", scanned: false },
		{ w: "88%", scanned: false },
	];

	return (
		<div className="relative">
			{/* Screen frame */}
			<div
				style={{
					width: 170,
					borderRadius: 8,
					border: "1px solid rgba(255,255,255,0.1)",
					background: "rgba(255,255,255,0.02)",
					padding: "10px 12px",
					display: "flex",
					flexDirection: "column",
					gap: 6,
				}}
			>
				{/* Window dots */}
				<div className="flex gap-[4px] mb-1">
					<div
						style={{
							width: 5,
							height: 5,
							borderRadius: "50%",
							background: "rgba(255,255,255,0.1)",
						}}
					/>
					<div
						style={{
							width: 5,
							height: 5,
							borderRadius: "50%",
							background: "rgba(255,255,255,0.1)",
						}}
					/>
					<div
						style={{
							width: 5,
							height: 5,
							borderRadius: "50%",
							background: "rgba(255,255,255,0.1)",
						}}
					/>
				</div>
				{/* Text lines */}
				{lines.map((line, i) => (
					<div
						key={i}
						style={{
							width: line.w,
							height: 6,
							borderRadius: 3,
							background: line.scanned
								? "linear-gradient(90deg, rgba(0,212,255,0.6), rgba(139,92,246,0.6))"
								: "rgba(255,255,255,0.08)",
							boxShadow: line.scanned
								? "0 0 12px rgba(0,212,255,0.3)"
								: "none",
							transition: "all 0.3s",
						}}
					/>
				))}
			</div>

			{/* Scan crosshair / selection box */}
			<div
				style={{
					position: "absolute",
					top: 38,
					left: -6,
					right: -6,
					height: 42,
					border: "1.5px dashed rgba(0,212,255,0.5)",
					borderRadius: 6,
					pointerEvents: "none",
				}}
			/>
			{/* Corner markers */}
			<div
				style={{
					position: "absolute",
					top: 34,
					left: -10,
					width: 8,
					height: 8,
					borderTop: "2px solid rgba(0,212,255,0.8)",
					borderLeft: "2px solid rgba(0,212,255,0.8)",
				}}
			/>
			<div
				style={{
					position: "absolute",
					top: 34,
					right: -10,
					width: 8,
					height: 8,
					borderTop: "2px solid rgba(0,212,255,0.8)",
					borderRight: "2px solid rgba(0,212,255,0.8)",
				}}
			/>
			<div
				style={{
					position: "absolute",
					bottom: 22,
					left: -10,
					width: 8,
					height: 8,
					borderBottom: "2px solid rgba(0,212,255,0.8)",
					borderLeft: "2px solid rgba(0,212,255,0.8)",
				}}
			/>
			<div
				style={{
					position: "absolute",
					bottom: 22,
					right: -10,
					width: 8,
					height: 8,
					borderBottom: "2px solid rgba(0,212,255,0.8)",
					borderRight: "2px solid rgba(0,212,255,0.8)",
				}}
			/>

			{/* "OCR" label */}
			<div
				style={{
					position: "absolute",
					top: 26,
					right: -40,
					fontSize: 9,
					fontWeight: 700,
					letterSpacing: "0.08em",
					color: "rgba(0,212,255,0.7)",
					textTransform: "uppercase",
				}}
			>
				OCR
			</div>
		</div>
	);
}

export default function OgPreviewPage() {
	return (
		<div
			style={{
				minHeight: "100vh",
				display: "flex",
				alignItems: "center",
				justifyContent: "center",
				background: "#111",
				padding: 40,
			}}
		>
			{/* ── OG Image Canvas (1200 × 630) ── */}
			<div
				id="og-canvas"
				style={{
					width: 1200,
					height: 630,
					position: "relative",
					overflow: "hidden",
					borderRadius: 0,
					background: "#050507",
				}}
			>
				{/* Background gradient blobs */}
				<div
					style={{
						position: "absolute",
						top: -120,
						left: -80,
						width: 500,
						height: 500,
						borderRadius: "50%",
						background:
							"radial-gradient(circle, rgba(0,212,255,0.12) 0%, transparent 70%)",
						filter: "blur(60px)",
					}}
				/>
				<div
					style={{
						position: "absolute",
						bottom: -150,
						right: -100,
						width: 550,
						height: 550,
						borderRadius: "50%",
						background:
							"radial-gradient(circle, rgba(139,92,246,0.10) 0%, transparent 70%)",
						filter: "blur(60px)",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "50%",
						left: "50%",
						transform: "translate(-50%, -50%)",
						width: 600,
						height: 300,
						borderRadius: "50%",
						background:
							"radial-gradient(circle, rgba(0,212,255,0.05) 0%, transparent 70%)",
						filter: "blur(40px)",
					}}
				/>

				{/* Grid pattern overlay */}
				<div
					style={{
						position: "absolute",
						inset: 0,
						backgroundImage: `
							linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
							linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px)
						`,
						backgroundSize: "40px 40px",
					}}
				/>

				{/* Content */}
				<div
					style={{
						position: "relative",
						zIndex: 10,
						height: "100%",
						display: "flex",
						alignItems: "center",
						padding: "0 80px",
						gap: 64,
					}}
				>
					{/* Left side: Branding */}
					<div style={{ flex: 1, minWidth: 0 }}>
						{/* App icon + name */}
						<div
							style={{
								display: "flex",
								alignItems: "center",
								gap: 14,
								marginBottom: 28,
							}}
						>
							<img
								src="/app-icon.png"
								alt="Superclip"
								style={{
									width: 52,
									height: 52,
									filter: "drop-shadow(0 4px 12px rgba(0,212,255,0.25))",
								}}
							/>
							<span
								style={{
									fontSize: 22,
									fontWeight: 700,
									color: "rgba(255,255,255,0.9)",
									letterSpacing: "-0.01em",
								}}
							>
								Superclip
							</span>
						</div>

						{/* Headline */}
						<h1
							style={{
								fontSize: 52,
								fontWeight: 800,
								lineHeight: 1.1,
								letterSpacing: "-0.03em",
								color: "#fff",
								margin: 0,
							}}
						>
							Your clipboard,
							<br />
							<span
								style={{
									background:
										"linear-gradient(135deg, #00D4FF 0%, #8B5CF6 100%)",
									WebkitBackgroundClip: "text",
									WebkitTextFillColor: "transparent",
								}}
							>
								supercharged
							</span>
						</h1>

						{/* Subtitle */}
						<p
							style={{
								fontSize: 18,
								lineHeight: 1.5,
								color: "rgba(255,255,255,0.45)",
								marginTop: 20,
								maxWidth: 420,
							}}
						>
							The clipboard manager macOS deserves. All the features of Paste — at half the price.
						</p>

						{/* Badges */}
						<div
							style={{
								display: "flex",
								gap: 10,
								marginTop: 28,
							}}
						>
							<span
								style={{
									display: "inline-flex",
									alignItems: "center",
									height: 28,
									padding: "0 14px",
									borderRadius: 14,
									fontSize: 12,
									fontWeight: 700,
									letterSpacing: "0.02em",
									background: "rgba(16,185,129,0.12)",
									border: "1px solid rgba(16,185,129,0.2)",
									color: "rgba(52,211,153,0.9)",
								}}
							>
								Free for first 1,000 users
							</span>
							<span
								style={{
									display: "inline-flex",
									alignItems: "center",
									height: 28,
									padding: "0 14px",
									borderRadius: 14,
									fontSize: 12,
									fontWeight: 600,
									background: "rgba(255,255,255,0.04)",
									border: "1px solid rgba(255,255,255,0.08)",
									color: "rgba(255,255,255,0.5)",
								}}
							>
								macOS 12+
							</span>
						</div>
					</div>

					{/* Right side: Abstract pixel art features */}
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							gap: 40,
							alignItems: "center",
							flexShrink: 0,
						}}
					>
						{/* Feature 1: Organized Pasteboard */}
						<div style={{ textAlign: "center" }}>
							<PasteboardArt />
							<p
								style={{
									marginTop: 10,
									fontSize: 11,
									fontWeight: 600,
									letterSpacing: "0.06em",
									textTransform: "uppercase",
									color: "rgba(255,255,255,0.25)",
								}}
							>
								Organized Pasteboard
							</p>
						</div>

						{/* Feature 2: Capture text anywhere */}
						<div style={{ textAlign: "center" }}>
							<CaptureArt />
							<p
								style={{
									marginTop: 10,
									fontSize: 11,
									fontWeight: 600,
									letterSpacing: "0.06em",
									textTransform: "uppercase",
									color: "rgba(255,255,255,0.25)",
								}}
							>
								Capture Text Anywhere
							</p>
						</div>
					</div>
				</div>

				{/* Bottom bar */}
				<div
					style={{
						position: "absolute",
						bottom: 0,
						left: 0,
						right: 0,
						height: 1,
						background:
							"linear-gradient(90deg, transparent, rgba(0,212,255,0.3), rgba(139,92,246,0.3), transparent)",
					}}
				/>

				{/* Subtle top border */}
				<div
					style={{
						position: "absolute",
						top: 0,
						left: 0,
						right: 0,
						height: 1,
						background:
							"linear-gradient(90deg, transparent, rgba(255,255,255,0.06), transparent)",
					}}
				/>
			</div>

			{/* Helper text */}
			<div
				style={{
					position: "fixed",
					bottom: 20,
					left: "50%",
					transform: "translateX(-50%)",
					fontSize: 13,
					color: "rgba(255,255,255,0.3)",
					textAlign: "center",
				}}
			>
				Screenshot the 1200×630 box above → save as{" "}
				<code
					style={{
						background: "rgba(255,255,255,0.08)",
						padding: "2px 6px",
						borderRadius: 4,
					}}
				>
					public/og-image.png
				</code>
			</div>
		</div>
	);
}
