import Nav from "@/components/Nav";
import Hero from "@/components/Hero";
import StatsBar from "@/components/StatsBar";
import Features from "@/components/Features";
import Screenshots from "@/components/Screenshots";
import HowItWorks from "@/components/HowItWorks";
import PrivacyBand from "@/components/PrivacyBand";
import ContactSection from "@/components/ContactSection";
import CtaSection from "@/components/CtaSection";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <main className="min-h-screen bg-surface-page">
      <Nav />
      <Hero />
      <StatsBar />
      <Features />
      <Screenshots />
      <HowItWorks />
      <PrivacyBand />
      <ContactSection />
      <CtaSection />
      <Footer />
    </main>
  );
}
