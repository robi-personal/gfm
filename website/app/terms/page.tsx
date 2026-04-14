import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms and Conditions — GFM",
  description: "Terms and Conditions for GFM — Google Forms Manager.",
};

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-white">
      <Nav />
      <section className="pt-32 pb-24 px-4">
        <div className="max-w-2xl mx-auto">
          <div className="mb-12">
            <span className="text-xs font-semibold tracking-widest text-[#772FC0] uppercase">
              Legal
            </span>
            <h1 className="mt-3 text-4xl font-bold text-[#1A1A2E]">
              Terms and Conditions
            </h1>
            <p className="mt-3 text-[#64748B]">
              Effective Date: April 14, 2026 &nbsp;·&nbsp; Last Updated: April 14, 2026
            </p>
          </div>

          <div className="space-y-10 text-[#64748B] leading-relaxed">
            <p className="text-lg text-[#1A1A2E]">
              By accessing or using <strong>GFM — Google Forms Manager</strong> ("GFM", "the app")
              at{" "}
              <a href="https://gformmanager.netlify.app" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                gformmanager.netlify.app
              </a>
              , you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree,
              you must not use the app. These Terms work alongside our{" "}
              <a href="/privacy" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                Privacy Policy
              </a>
              .
            </p>

            <Section title="1. Who You Are Agreeing With">
              <p>
                These Terms are entered into between you and us.
                Website:{" "}
                <a href="https://gformmanager.netlify.app" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  gformmanager.netlify.app
                </a>
                {" "}· Contact:{" "}
                <a href="mailto:formmanager000@gmail.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  formmanager000@gmail.com
                </a>
              </p>
            </Section>

            <Section title="2. What GFM Does">
              <p className="mb-4">
                GFM is a mobile client application that connects to Google APIs (Google Forms and
                Google Drive) on your behalf to let you:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Create, edit, duplicate, and delete Google Forms.",
                  "Manage form questions, sections, and settings.",
                  "Share form links.",
                  "View responses to forms you have access to.",
                  "Export responses (where available as a paid feature).",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                GFM does not host your forms or responses. All form data is stored in your own
                Google account and remains your property.
              </p>
            </Section>

            <Section title="3. Eligibility">
              <p className="mb-4">To use GFM you must:</p>
              <ul className="space-y-3 ml-4">
                {[
                  "Be at least 18 years old, or the age of legal majority in your jurisdiction, whichever is greater.",
                  "Have a valid Google account.",
                  "Have the legal capacity to enter into a binding agreement.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                If you are using GFM on behalf of an organization, you represent that you have
                authority to bind that organization to these Terms.
              </p>
            </Section>

            <Section title="4. Your Google Account and Authorization">
              <p className="mb-4">
                You authorize GFM to access your Google account data through Google OAuth, limited
                to the scopes described in our{" "}
                <a href="/privacy" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  Privacy Policy
                </a>
                . You may revoke this authorization at any time through your Google Account security
                settings. You are responsible for:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Keeping your Google account credentials secure.",
                  "The activity that occurs under your account through GFM.",
                  "Ensuring you have the right to access and modify any forms you open in the app.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="5. Acceptable Use">
              <p className="mb-4">You agree not to:</p>
              <ul className="space-y-3 ml-4">
                {[
                  "Use GFM for any unlawful purpose, or to collect data in violation of applicable laws (including data protection and privacy laws).",
                  "Create, distribute, or solicit responses to forms containing illegal content, hate speech, harassment, malware, phishing material, or content that infringes the rights of others.",
                  "Attempt to reverse-engineer, decompile, or extract source code from the app, except as expressly permitted by law.",
                  "Interfere with or abuse the Google APIs that GFM relies on, or attempt to circumvent rate limits or quotas.",
                  "Use GFM to send spam or unsolicited communications.",
                  "Attempt to access data or accounts that do not belong to you.",
                  "Use GFM in any way that could damage, disable, overburden, or impair the service.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                You are solely responsible for the legality of forms you create and the data you
                collect through them.
              </p>
            </Section>

            <Section title="6. Your Content">
              <p>
                You retain all rights to the forms, questions, responses, and other content you
                create or collect through GFM. We claim no ownership over your content.
                Because all content lives in your Google account, your use of that content is also
                subject to Google's terms of service for Google Forms and Google Drive.
              </p>
            </Section>

            <Section title="7. Uploaded Files and Link-Based Access">
              <p className="mb-4">
                When you upload an image to a form through GFM, the image is stored in your Google
                Drive and its sharing permission is set to "anyone with the link can view" so that
                form respondents can see it. GFM displays an in-app confirmation before the first
                such upload. You are solely responsible for:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Managing the sharing permissions of files you upload.",
                  "Not embedding sensitive, confidential, or personally identifying material in forms.",
                  "The consequences of any link-based exposure of files you choose to upload.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="8. Paid Features and Subscriptions">
              <p className="mb-4">
                Some features of GFM are available only to users on a paid subscription ("Pro
                features"), which may include advanced question types, quiz mode, response export,
                and removal of advertisements.
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Pricing and billing for Pro features are presented in the app at the time of purchase and are processed by the relevant app store (Google Play or Apple App Store), not by us directly.",
                  "Refunds, cancellations, and subscription management are governed by the terms of the app store you used to subscribe.",
                  "We may add, remove, or modify Pro features over time. Material changes that reduce features in your active subscription will be communicated through the app.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                The free tier of GFM may be supported by non-intrusive advertisements. By using
                the free tier, you agree to be shown such advertisements.
              </p>
            </Section>

            <Section title="9. Third-Party Services">
              <p className="mb-4">
                GFM relies on third-party services to function, including:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Google APIs (Google Forms, Google Drive, Google Sign-In)",
                  "Google Firebase (Analytics and Crashlytics)",
                  "Google Play Services or Apple App Store services for app distribution and billing",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                These services are operated by third parties under their own terms and privacy
                policies. We are not responsible for outages, errors, or changes to these services,
                nor for the continued availability of any specific Google API on which GFM depends.
                If a third-party service we depend on changes or becomes unavailable, GFM features
                that rely on it may be modified or removed.
              </p>
            </Section>

            <Section title="10. Service Availability">
              <p>
                We do not guarantee that GFM will be uninterrupted, error-free, or available at all
                times. We may modify, suspend, or discontinue the app or any feature, in whole or in
                part, at any time, with or without notice. We will make reasonable efforts to
                communicate planned changes that materially affect users on active paid subscriptions.
              </p>
            </Section>

            <Section title="11. Disclaimer of Warranties">
              <p>
                GFM is provided <strong>"as is" and "as available," without warranties of any kind</strong>,
                whether express, implied, statutory, or otherwise. To the maximum extent permitted
                by applicable law, we disclaim all warranties, including but not limited to
                warranties of merchantability, fitness for a particular purpose, non-infringement,
                and that the service will meet your requirements or operate without interruption. We
                do not warrant the accuracy, completeness, or reliability of any data displayed
                through GFM, including data retrieved from Google APIs. Some jurisdictions do not
                allow the exclusion of certain warranties; in those jurisdictions, the above
                exclusions apply to the maximum extent permitted by law.
              </p>
            </Section>

            <Section title="12. Limitation of Liability">
              <p className="mb-4">
                To the maximum extent permitted by applicable law, we shall not be liable for
                any indirect, incidental, special, consequential, exemplary, or punitive damages,
                including but not limited to:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Loss of data, forms, or responses.",
                  "Loss of profits, revenue, goodwill, or business opportunity.",
                  "Service interruptions, downtime, or sync failures.",
                  "Damages resulting from your reliance on the service or on data displayed by it.",
                  "Damages arising from third-party services on which GFM depends.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                Our total cumulative liability arising out of or relating to these Terms or your use
                of GFM shall not exceed the greater of (a) the amount you paid us in the
                twelve months preceding the claim, or (b) USD $50. Some jurisdictions do not allow
                certain limitations of liability; in those jurisdictions, our liability is limited
                to the maximum extent permitted by law.
              </p>
            </Section>

            <Section title="13. Indemnification">
              <p className="mb-4">
                You agree to indemnify and hold harmless us, and any contributors, from any
                claims, damages, losses, liabilities, and expenses (including reasonable legal fees)
                arising from:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "Your use of GFM in violation of these Terms.",
                  "Forms you create or responses you collect through GFM.",
                  "Your violation of any applicable law or third-party right.",
                  "Files you upload through GFM and any consequences of their link-based accessibility.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="14. Termination">
              <p className="mb-4">
                You may stop using GFM at any time and revoke its access from your Google Account.
                We may suspend or terminate your access to GFM, with or without notice, if:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "You materially breach these Terms.",
                  "We detect abuse, misuse, or activity that risks the security or stability of the service or of the Google APIs we depend on.",
                  "We are required to do so by law, court order, or platform policy (including Google's API terms or app store policies).",
                  "We discontinue the app.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                Termination does not affect your ownership of forms and data already stored in your
                Google account. Sections §6, §11, §12, §13, §16, and §17 survive termination.
              </p>
            </Section>

            <Section title="15. Changes to These Terms">
              <p>
                We may update these Terms from time to time. The current version is always available
                at{" "}
                <a href="https://gformmanager.netlify.app/terms" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  gformmanager.netlify.app/terms
                </a>
                . For material changes that affect your rights or obligations, we will notify you
                within the app and where appropriate require re-acknowledgement before continued use.
                Minor clarifications will be reflected via an updated "Last Updated" date. Your
                continued use of GFM after changes take effect constitutes acceptance of the updated Terms.
              </p>
            </Section>

            <Section title="16. Governing Law">
              <p>
                These Terms are governed by and interpreted in accordance with the laws of
                Bangladesh, without regard to its conflict-of-law provisions.
              </p>
            </Section>

            <Section title="17. Dispute Resolution">
              <p>
                Any dispute arising out of or relating to these Terms or your use of GFM shall
                first be addressed through good-faith negotiation by contacting{" "}
                <a href="mailto:formmanager000@gmail.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  formmanager000@gmail.com
                </a>
                . If the dispute cannot be resolved within 60 days of written notice, it shall be
                subject to the exclusive jurisdiction of the competent courts located in Bangladesh.
                Nothing in this section prevents either party from seeking injunctive or other
                equitable relief to protect intellectual property rights or confidential information.
              </p>
            </Section>

            <Section title="18. Miscellaneous">
              <ul className="space-y-3 ml-4">
                {[
                  "Entire agreement. These Terms, together with the Privacy Policy, constitute the entire agreement between you and us regarding GFM.",
                  "Severability. If any provision of these Terms is held invalid or unenforceable, the remaining provisions remain in full force.",
                  "No waiver. Our failure to enforce any provision is not a waiver of our right to do so later.",
                  "Assignment. You may not assign these Terms without our prior written consent. We may assign these Terms in connection with a merger, acquisition, or sale of assets.",
                  "No agency. Nothing in these Terms creates an agency, partnership, employment, or joint venture relationship between you and us.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="19. Contact">
              <p>
                Email:{" "}
                <a href="mailto:formmanager000@gmail.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  formmanager000@gmail.com
                </a>
                <br />
                Website:{" "}
                <a href="https://gformmanager.netlify.app" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  gformmanager.netlify.app
                </a>
              </p>
            </Section>

          </div>
        </div>
      </section>
      <Footer />
    </main>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="border-l-4 border-[#772FC0] pl-4 text-xl font-semibold text-[#1A1A2E] mb-4">
        {title}
      </h2>
      {children}
    </div>
  );
}

function Bullet({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex gap-3">
      <span className="mt-1.5 h-1.5 w-1.5 rounded-full bg-[#772FC0] flex-shrink-0" />
      <span>{children}</span>
    </li>
  );
}
