import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
});

const siteUrl = "https://superclip.app";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "Superclip — The Clipboard Manager macOS Deserves",
    template: "%s | Superclip",
  },
  description:
    "Superclip is a native macOS clipboard manager built with SwiftUI. Clipboard history, pinboards, paste stack, OCR, and screen capture — all for half the price of Paste. Free for the first 1,000 users.",
  keywords: [
    "clipboard manager",
    "clipboard manager for mac",
    "mac clipboard",
    "mac clipboard history",
    "macOS clipboard manager",
    "paste alternative",
    "paste app alternative",
    "clipboard history macOS",
    "copy paste manager mac",
    "clipboard tool mac",
    "paste stack",
    "clipboard OCR",
    "screen capture mac",
    "cleanshot alternative",
    "pinboard clipboard",
    "keyboard clipboard manager",
    "superclip",
  ],
  authors: [{ name: "Superclip" }],
  creator: "Superclip",
  publisher: "Superclip",
  category: "Productivity",
  applicationName: "Superclip",
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  alternates: {
    canonical: siteUrl,
  },
  openGraph: {
    title: "Superclip — The Clipboard Manager macOS Deserves",
    description:
      "Native macOS clipboard manager with history, pinboards, paste stack, OCR, and screen capture. Half the price of Paste. Free for the first 1,000 users.",
    type: "website",
    locale: "en_US",
    url: siteUrl,
    siteName: "Superclip",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Superclip — The Clipboard Manager macOS Deserves",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Superclip — The Clipboard Manager macOS Deserves",
    description:
      "Native macOS clipboard manager. Clipboard history, paste stack, OCR, screen capture — half the price of Paste. Free for first 1,000 users.",
    images: ["/og-image.png"],
  },
  icons: {
    icon: "/app-icon.png",
    apple: "/app-icon.png",
  },
};

function JsonLd() {
  const softwareApp = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Superclip",
    description:
      "Native macOS clipboard manager with clipboard history, pinboards, paste stack, built-in OCR, and screen capture. Half the price of Paste.",
    url: siteUrl,
    applicationCategory: "UtilitiesApplication",
    operatingSystem: "macOS 12+",
    offers: [
      {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        description: "Free for the first 1,000 users — forever",
      },
      {
        "@type": "Offer",
        price: "14.99",
        priceCurrency: "USD",
        billingDuration: "P1Y",
        description: "Annual subscription after free spots are claimed",
      },
      {
        "@type": "Offer",
        price: "1.99",
        priceCurrency: "USD",
        billingDuration: "P1M",
        description: "Monthly subscription after free spots are claimed",
      },
    ],
    aggregateRating: {
      "@type": "AggregateRating",
      ratingValue: "4.9",
      ratingCount: "257",
      bestRating: "5",
    },
    featureList: [
      "Clipboard history",
      "Smart pinboards",
      "Paste stack",
      "Built-in OCR",
      "Screen capture and recording",
      "GIF and MP4 recording",
      "Image and video editor",
      "Keyboard-first navigation",
      "Privacy controls",
      "App exclusion",
      "Native SwiftUI performance",
    ],
    screenshot: `${siteUrl}/og-image.png`,
    softwareVersion: "1.0",
    author: {
      "@type": "Organization",
      name: "Superclip",
      url: siteUrl,
    },
  };

  const faqPage = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: [
      {
        "@type": "Question",
        name: "Is Superclip really free?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "Yes. The first 1,000 users get Superclip completely free — forever. No trial, no credit card, no catch. After those spots are claimed, new users pay $14.99/year.",
        },
      },
      {
        "@type": "Question",
        name: "How is Superclip different from Paste?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "Superclip has every feature Paste has — clipboard history, pinboards, OCR, paste stack — at half the price ($14.99/yr vs $29.99/yr). Plus we're adding built-in screen capture and recording (worth $99/yr with CleanShot X) for free.",
        },
      },
      {
        "@type": "Question",
        name: "Is my clipboard data private?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "100%. Everything stays on your Mac. There's no cloud sync, no analytics, no tracking. You can exclude sensitive apps and auto-clear history on quit.",
        },
      },
      {
        "@type": "Question",
        name: "Will Superclip slow down my Mac?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "No. Superclip is built natively with SwiftUI — no Electron, no web wrappers. It uses less than 30MB of memory and launches in under 0.3 seconds.",
        },
      },
      {
        "@type": "Question",
        name: "What if I already use Paste?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "You can run both side-by-side. Try Superclip free, and switch when you're ready. Your muscle memory transfers — same keyboard shortcuts, same workflows.",
        },
      },
      {
        "@type": "Question",
        name: "What macOS versions does Superclip support?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "Superclip requires macOS 12 (Monterey) or later. It runs natively on both Apple Silicon and Intel Macs.",
        },
      },
    ],
  };

  const website = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "Superclip",
    url: siteUrl,
    description:
      "The clipboard manager macOS deserves. Faster, smarter, and half the price of Paste.",
    potentialAction: {
      "@type": "SearchAction",
      target: `${siteUrl}/?q={search_term_string}`,
      "query-input": "required name=search_term_string",
    },
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareApp) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqPage) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(website) }}
      />
    </>
  );
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <head>
        <JsonLd />
      </head>
      <body className={`${inter.variable} antialiased noise`}>
        {children}
      </body>
    </html>
  );
}
