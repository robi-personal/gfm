import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "GFM",
  description:
    "Create, edit, and manage Google Forms from anywhere. Native speed, full functionality — no compromises. Privacy-first: all data stays in Google Drive.",
  keywords: ["Google Forms", "mobile app", "forms manager", "educators", "teachers"],
  openGraph: {
    title: "GFM — Google Forms for Your Phone",
    description:
      "Create, edit, and manage Google Forms from anywhere. Native speed, full functionality — no compromises.",
    type: "website",
  },
  verification: {
    google: "HlI3dZzboPdJnX-JjUSoQw-XeYP49ezYWILGIqCs6vk",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="bg-surface-page text-ink antialiased">
        {children}
      </body>
    </html>
  );
}
