import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";
import { StickyBar } from "@/components/ui/StickyBar";
import { Hero } from "@/components/sections/Hero";
import { SocialProof } from "@/components/sections/SocialProof";
import { Features } from "@/components/sections/Features";
import { Comparison } from "@/components/sections/Comparison";
import { Pricing } from "@/components/sections/Pricing";
import { Shortcuts } from "@/components/sections/Shortcuts";
import { Roadmap } from "@/components/sections/Roadmap";
import { FAQ } from "@/components/sections/FAQ";
import { FeatureRequests } from "@/components/sections/FeatureRequests";
import { Download } from "@/components/sections/Download";

export default function HomePage() {
  return (
    <>
      <Header />
      <main>
        {/* 1. Hook — headline, value prop, primary CTA */}
        <Hero />
        {/* 2. Prove it — social proof immediately after hero */}
        <SocialProof />
        {/* 3. Show it — what you get */}
        <Features />
        {/* 4. Compare it — why switch from Paste + CleanShot value */}
        <Comparison />
        {/* 5. Price it — free tier + urgency */}
        <Pricing />
        {/* 6. Power users — keyboard shortcuts (earned interest) */}
        <Shortcuts />
        {/* 7. Future — roadmap builds confidence */}
        <Roadmap />
        {/* 8. Object — FAQ handles doubts */}
        <FAQ />
        {/* 9. Community — feature requests shows investment */}
        <FeatureRequests />
        {/* 10. Close — final download CTA */}
        <Download />
      </main>
      <Footer />
      <StickyBar />
    </>
  );
}
