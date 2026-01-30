import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Superclip — The Clipboard Manager macOS Deserves",
  description:
    "Superclip is a native macOS clipboard manager. Faster, smarter, and half the price of Paste. Free for the first 1,000 users.",
  keywords: [
    "clipboard manager",
    "mac clipboard",
    "paste alternative",
    "macOS clipboard history",
    "clipboard manager for mac",
  ],
  openGraph: {
    title: "Superclip — The Clipboard Manager macOS Deserves",
    description:
      "Faster, smarter, and half the price of Paste. Free for the first 1,000 users.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Superclip — The Clipboard Manager macOS Deserves",
    description:
      "Faster, smarter, and half the price of Paste. Free for the first 1,000 users.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} antialiased noise`}>
        {children}
      </body>
    </html>
  );
}
