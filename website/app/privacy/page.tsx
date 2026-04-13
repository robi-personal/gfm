import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — GFM",
  description: "GFM privacy policy. Learn how we handle your data — hint: we barely touch it.",
};

export default function PrivacyPage() {
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
              Privacy Policy
            </h1>
            <p className="mt-3 text-[#64748B]">
              Effective Date: April 14, 2026 &nbsp;·&nbsp; Last Updated: April 14, 2026
            </p>
          </div>

          <div className="space-y-10 text-[#64748B] leading-relaxed">
            <p className="text-lg text-[#1A1A2E]">
              This Privacy Policy describes how <strong>AlphaIIT</strong> ("we", "our", "us")
              processes information in connection with our application{" "}
              <strong>GFM — Google Forms Manager</strong> ("GFM", "the app").
              Website:{" "}
              <a href="https://alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                alphaiit.com
              </a>
              {" "}· Contact:{" "}
              <a href="mailto:support@alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                support@alphaiit.com
              </a>
            </p>

            <Section title="1. What GFM Is">
              <p>
                GFM is a mobile client application that interacts directly with Google APIs
                (Google Forms API and Google Drive API) on behalf of the signed-in user.
                GFM does not operate a backend server for storing user-generated form content.
                All form structures, questions, settings, and responses remain within the
                user's own Google account. The application uses Firebase services for crash
                reporting and aggregate usage analytics, as detailed in §8.
              </p>
            </Section>

            <Section title="2. Google API Services — Limited Use Compliance">
              <p className="mb-4">
                GFM's use and transfer of information received from Google APIs adheres to the{" "}
                <a href="https://developers.google.com/terms/api-services-user-data-policy" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  Google API Services User Data Policy
                </a>
                , including the Limited Use requirements. Specifically, we affirm:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "We use Google user data only to provide and improve user-facing features within GFM.",
                  "We do not sell Google user data.",
                  "We do not use Google user data for advertising purposes.",
                  "We do not use Google user data to build user profiles or to train AI/ML models.",
                  "We do not transfer Google user data to third parties, except to Google services as required for the application to function, or as required by law.",
                  "We do not allow humans to read Google user data, except with the user's explicit consent for support, for security investigations, or to comply with applicable law.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="3. Data Storage and On-Device Caching">
              <p className="mb-4">
                We do not store, log, or persist Google user data on our servers. To enable
                offline editing and a responsive user experience, GFM may temporarily cache
                form content on the user's device. This local cache:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "is private to the user's device,",
                  "is encrypted at rest where supported by the operating system (Android Keystore, iOS Keychain),",
                  "is cleared automatically on sign-out or app uninstall,",
                  "is never transmitted to AlphaIIT servers or to any third party other than Google APIs.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="4. Google API Scopes and Why We Need Them">
              <div className="space-y-6">
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-2">
                    <code className="text-sm bg-[#F3E8FF] px-1.5 py-0.5 rounded">drive.file</code>
                  </p>
                  <p>
                    Used to create new Google Forms in the user's Drive; open, modify, and delete
                    forms the user creates within GFM or explicitly opens by pasting a link; and
                    upload images that the user chooses to embed in their forms. This scope restricts
                    GFM to files the app itself created or that the user explicitly opened — GFM
                    cannot see other files in the user's Drive.
                  </p>
                </div>
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-2">
                    <code className="text-sm bg-[#F3E8FF] px-1.5 py-0.5 rounded">forms.body</code>
                  </p>
                  <p>
                    Used to create form titles, descriptions, and settings; add, edit, reorder, and
                    delete questions, sections, and media items; configure quiz settings, grading, and
                    form publish state.
                  </p>
                </div>
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-2">
                    <code className="text-sm bg-[#F3E8FF] px-1.5 py-0.5 rounded">forms.responses.readonly</code>
                  </p>
                  <p>
                    Used to display response counts and individual responses to the signed-in user,
                    for forms they have access to, and to power the in-app "Responses" view and
                    CSV/Excel export (paid feature). Access occurs only during active user
                    interaction. We do not perform background polling, bulk extraction, or external
                    processing of response data.
                  </p>
                </div>
              </div>
            </Section>

            <Section title="5. Sensitive Data in Form Responses">
              <p className="mb-4">
                Form responses may contain personal or sensitive information. GFM enforces:
              </p>
              <ul className="space-y-3 ml-4">
                {[
                  "No storage of response data on AlphaIIT servers.",
                  "No transmission of response data outside of Google APIs and the user's device.",
                  "No analysis, profiling, or aggregation of response content.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                Response data is displayed only to the signed-in Google user who has access to the form.
              </p>
            </Section>

            <Section title="6. Authentication and Tokens">
              <ul className="space-y-3 ml-4">
                {[
                  "Refresh tokens are stored encrypted on-device using the operating system's secure storage (Android Keystore, iOS Keychain).",
                  "Access tokens are held in memory only during an active session.",
                  "All tokens are deleted from the device when the user signs out, uninstalls the app, or revokes access from their Google Account.",
                  "We never transmit OAuth tokens to AlphaIIT servers or to any third party other than Google.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="7. Analytics and Crash Reporting">
              <p className="mb-4">
                GFM uses two Firebase services from Google to maintain app quality:
              </p>
              <ul className="space-y-3 ml-4">
                <Bullet>
                  <strong className="text-[#1A1A2E]">Firebase Analytics</strong> — to understand
                  aggregate, anonymous usage patterns (which screens are visited, which features are used).
                </Bullet>
                <Bullet>
                  <strong className="text-[#1A1A2E]">Firebase Crashlytics</strong> — to receive
                  automated crash reports so we can fix bugs.
                </Bullet>
              </ul>
              <p className="mt-4 mb-4">These services may collect:</p>
              <ul className="space-y-3 ml-4">
                {[
                  "Device type, operating system version, app version, language, country.",
                  "Anonymous, randomly-generated installation identifiers.",
                  "IP address (collected by Firebase SDK; used for approximate location and abuse prevention).",
                  "Crash stack traces and the application state at the time of a crash.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                No form content, question text, response data, or personal user identifiers
                (including email addresses) are sent to Firebase. Firebase data is used strictly
                to maintain app stability and improve the product — never for advertising,
                profiling, or sale to third parties.
                Firebase data handling is governed by{" "}
                <a href="https://firebase.google.com/support/privacy" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  Google&apos;s privacy policies
                </a>.
              </p>
            </Section>

            <Section title="8. Data Retention">
              <ul className="space-y-3 ml-4">
                {[
                  "Google user data: not retained by AlphaIIT. All form data lives in the user's Google account.",
                  "On-device cache: retained until the user signs out, uninstalls the app, or clears app data.",
                  "Firebase Analytics and Crashlytics: retained according to Firebase's default retention settings, controlled by Google.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="9. Data Deletion and Revocation">
              <div className="space-y-4">
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-1">To revoke GFM&apos;s access:</p>
                  <p>
                    Go to your{" "}
                    <a href="https://myaccount.google.com/permissions" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                      Google Account → Security → Third-party apps with account access
                    </a>{" "}
                    and remove GFM. Access is revoked immediately.
                  </p>
                </div>
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-1">To delete data created with GFM:</p>
                  <p>
                    Forms created in GFM are stored in your Google Drive. Delete them directly from
                    Drive or the Google Forms web interface.
                  </p>
                </div>
                <div>
                  <p className="font-semibold text-[#1A1A2E] mb-1">To clear on-device data:</p>
                  <p>Uninstall the app, or use your device&apos;s app settings to clear app data.</p>
                </div>
              </div>
            </Section>

            <Section title="10. Data Sharing">
              <p>
                We do not sell, rent, lease, or share user data with third parties for any purpose
                other than the service provider relationships described in this policy (Google APIs,
                Firebase). We do not share data with advertisers. We do not transfer Google user
                data outside of Google's services.
              </p>
            </Section>

            <Section title="11. Uploaded Images and Link-Based Access">
              <p>
                When a user adds an image to a form through GFM, the image is uploaded to the
                user's own Google Drive and its sharing permission is set to "anyone with the link
                can view," which is required by the Google Forms API for embedded images to render.
                GFM displays an in-app confirmation before any image is uploaded for the first time.
                Once a file is set to "anyone with the link," anyone who obtains the link may view
                the file. Users are responsible for managing the visibility of files they upload.
              </p>
            </Section>

            <Section title="12. Security Measures">
              <ul className="space-y-3 ml-4">
                {[
                  "HTTPS encryption for all network communications.",
                  "OAuth 2.0 authentication via Google's official SDK — GFM never sees the user's Google password.",
                  "On-device encryption of authentication tokens via OS-provided secure storage.",
                  "No storage of Google user data on AlphaIIT infrastructure, eliminating server-side breach risk for that data class.",
                  "Regular updates to the application and its dependencies to address security advisories.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
            </Section>

            <Section title="13. Children and Educational Use">
              <p>
                GFM is intended for adults (typically aged 18 and over) and is not directed to
                children under 13 (or under 16 in jurisdictions where that is the applicable
                threshold under GDPR-K). We do not knowingly collect personal information from
                children. When teachers use GFM to collect responses from students, those responses
                are stored within the teacher's Google account — AlphaIIT does not receive, store,
                or process student response data. If you believe a child has provided personal
                information through GFM, contact{" "}
                <a href="mailto:support@alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  support@alphaiit.com
                </a>.
              </p>
            </Section>

            <Section title="14. International Data Transfers">
              <p>
                GFM is operated from Bangladesh. Google and Firebase services may process data on
                servers located in countries other than the user's own, including the United States.
                Where required by applicable law (including GDPR), such transfers rely on the legal
                mechanisms Google maintains for its services. By using GFM, you acknowledge that
                data processed by Google APIs and Firebase is handled in accordance with Google's
                own data transfer frameworks.
              </p>
            </Section>

            <Section title="15. Your Rights">
              <p className="mb-4">Depending on your jurisdiction, you may have the right to:</p>
              <ul className="space-y-3 ml-4">
                {[
                  "Access the personal data we hold about you (in our case, none beyond Firebase telemetry tied to a random installation ID).",
                  "Request correction or deletion of your data.",
                  "Withdraw your consent to data processing at any time by revoking the app's Google access (see §9).",
                  "Lodge a complaint with your local data protection authority.",
                ].map((item, i) => (
                  <Bullet key={i}>{item}</Bullet>
                ))}
              </ul>
              <p className="mt-4">
                To exercise any of these rights, contact{" "}
                <a href="mailto:support@alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  support@alphaiit.com
                </a>.
              </p>
            </Section>

            <Section title="16. Changes to This Policy">
              <p>
                We may update this Privacy Policy from time to time. The current version is always
                available at{" "}
                <a href="https://alphaiit.com/privacy" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  alphaiit.com/privacy
                </a>
                . For material changes that affect how we process your data, we will notify you
                within the app and where appropriate require re-acknowledgement before continued use.
                Minor clarifications will be reflected via an updated "Last Updated" date.
              </p>
            </Section>

            <Section title="17. Governing Law">
              <p>
                This Privacy Policy is governed by the laws of Bangladesh, without regard to its
                conflict-of-law provisions.
              </p>
            </Section>

            <Section title="18. Contact">
              <p>
                <strong className="text-[#1A1A2E]">AlphaIIT</strong>
                <br />
                Email:{" "}
                <a href="mailto:support@alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  support@alphaiit.com
                </a>
                <br />
                Website:{" "}
                <a href="https://alphaiit.com" className="text-[#772FC0] hover:text-[#5B1F94] underline underline-offset-4 transition-colors">
                  alphaiit.com
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
