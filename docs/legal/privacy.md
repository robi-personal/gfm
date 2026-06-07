# Privacy Policy

**Effective date:** 2026-05-27
**Last updated:** 2026-06-07

> This document is the canonical privacy policy for GFM. The HTML version published at `gfm.alphaiit.com/privacy.html` is rendered from this source. **Not legal advice — review with counsel before launch.**

---

## 1. Who we are

GFM ("GFM", "the app", "we", "our", "us") is operated by **AlphaIIT**, an independent software developer based in Bangladesh.

- **Website:** [gfm.alphaiit.com](https://gfm.alphaiit.com)
- **Contact (privacy + legal):** [formmanager000@gmail.com](mailto:formmanager000@gmail.com)

This policy applies to the GFM mobile app on iOS, and to the website at `gfm.alphaiit.com`.

If you only use the website to read this policy or the Terms, the only personal data we process is whatever your browser sends automatically (IP address, user agent) and only for as long as needed to serve the page. The website has no cookies, analytics, or trackers.

---

## 2. Summary in plain English

- **Your Google Forms and the responses to them are not disclosed to us.** They live in your own Google Drive under your Google account. Google does not share their contents with us, and we have no ability to read, modify, or delete them on our servers. Only you, through your Google account, can do that.
- We store two things tied to your account: **(1) who you are** (your Google account ID and email so we can recognize you on next sign-in) and **(2) your subscription and quota status** (so we know whether you've paid and how much AI quota you have left). That's the extent of what we keep about you on our servers.
- If you ask the AI Form Builder to generate a draft, your prompt (and any PDF / URL content you provide for it) is sent to **Google's Gemini API** to produce the draft. We do not train any model on your inputs.
- If you subscribe, payment is handled by **Apple** and reconciled through **RevenueCat**. We never see your card details.
- We use **Firebase** for crash reporting and anonymized usage analytics. Form titles, question text, and response content are explicitly excluded.
- We **never** sell your data and **never** show ads.

Details below.

---

## 3. What we collect

### 3.1 What we keep on our servers about you

Strictly:

| Data | When | Why |
|---|---|---|
| Google account ID (`sub` claim) and email | When you sign in with Google | Recognize you on next sign-in; tie your subscription to your account |
| Subscription / premium status (active or not) | When you start, change, or cancel a subscription | Enable premium features |
| Quota balance | When the free monthly grant is applied or a subscription credits new quota | Track how many AI generations you have available |
| Apple `original_transaction_id` | When you purchase a subscription | Prevent one Apple ID from crediting multiple Google accounts (anti-abuse) |
| Contact-form messages on the website | When you submit the contact form | Reply to you |

That is the extent of what we persist about you on our servers.

### 3.2 Operational data we handle but do not retain as identifiable form content

These items support specific features. They are not "form data" — they do not contain the text of your questions, options, responses, or other Google Forms content.

| Data | Lifetime | Purpose |
|---|---|---|
| FCM device token (only if you grant notification permission) | Until you sign out, uninstall, or the token is invalidated by FCM | Allow us to send a push notification when a form receives a new response. The notification carries the form **title** and that a new response arrived — not the response content. |
| Google Forms `watch` registration (only if you enable notifications on a specific form, premium only) | Auto-expires after 7 days (Google's limit) | Subscribe to Google Cloud Pub/Sub deliveries so we know when to fire the notification above. |
| AI request fingerprint (a SHA-256 hash of your canonical request body) and the AI's draft response | At most 60 days, then automatically purged | Prevent double-charging on retries (idempotency). The raw text of your prompt and any uploaded PDF bytes are not persisted after the request completes; only the hash and the AI-generated draft (which has not yet been written to your Drive) are cached for the deduplication window. |
| RevenueCat subscription-event audit log | Indefinite — minimal data per event | Reconcile out-of-order webhook deliveries from RevenueCat. |
| Crash reports, anonymized usage events (Firebase) | Per Firebase's default retention | Diagnose bugs; understand which features are used. Form titles, question text, and response content are explicitly excluded. |

### 3.3 What we do NOT collect, store, or have access to

To be explicit, we do **not** have, do **not** store, and have **no technical ability to retrieve**:

- The **content** of your Google Forms (titles, question text, descriptions, options, branching rules) once they exist in your Google Drive. Google does not disclose your form data to us. Only you, through your Google account, can read or modify it.
- The **content** of form responses (respondents' answers, files they uploaded, their identities). Responses are received by Google directly from respondents and stored in your Google account. They never pass through our servers.
- The ability to **delete** any Google Form or response on your behalf. Deletion happens entirely inside your Google Drive, by you.
- Your Google Drive contents outside of files GFM created or that you explicitly imported.
- The **plain-text content** of your AI prompts after the AI generation completes (see §3.2 — we keep only a hash for retry deduplication).
- Your physical location.
- Your contacts, photos (other than ones you explicitly pick to insert into a form), microphone, or camera.
- Any payment-card data.

---

## 4. How we use your data

Strictly to operate GFM. Specifically:

1. **Authentication** — verify your Google ID token on every request to our middleware.
2. **Authorization** — check your subscription / quota state before serving AI generations or premium features.
3. **Service delivery** — call Google APIs (Forms, Drive) on your behalf, generate AI forms, fan out push notifications.
4. **Abuse and fraud prevention** — rate-limit and detect grind-style abuse of the AI quota.
5. **Product analytics** — anonymized event counts to understand what's used and what's not.
6. **Crash diagnostics** — fix bugs.
7. **Customer support** — reply to messages you send to `formmanager000@gmail.com`.

We **do not**:

- Sell or rent your data.
- Show advertising.
- Use your AI inputs to train any model (and our AI provider, Google, also does not train Gemini on API-tier requests — see §5.2).
- Share your data with any party other than the processors listed in §5.

---

## 5. Third-party processors

The following processors receive specific categories of your data so the app can function. Each is listed with its role and a link to its own privacy policy.

All third-party processors listed below are contractually required to provide the **same or equal level of protection** of user data as stated in this Privacy Policy and as required by applicable law. We share only the minimum data needed for each processor to perform its role.

### 5.1 Google APIs (Forms, Drive)

- **What they receive:** Your OAuth access token; the API requests you make (read/write forms, list/upload Drive files).
- **Data location:** Google's infrastructure (the same Drive that already holds your forms).
- **Why:** GFM is a companion to Google Forms; it cannot work without these APIs.
- **Scopes:** `drive.file` (limits access to files GFM created or you explicitly imported), `forms.body`, `forms.responses.readonly`.
- **Policy:** [policies.google.com/privacy](https://policies.google.com/privacy)

### 5.2 Google Gemini (AI form generation)

- **What they receive:** The prompt text and / or PDF / YouTube URL / website URL contents you submit through the AI Form Builder, plus a system prompt that constrains the output format.
- **Data location:** Google's Gemini API (US / EU regions).
- **Why:** To generate a draft form from your input.
- **Training:** Per Google's API-tier terms, prompts sent to the paid Gemini API are **not used to train models**. We use the paid tier.
- **Policy:** [policies.google.com/privacy](https://policies.google.com/privacy)

### 5.3 RevenueCat (subscription state)

- **What they receive:** Your Google account ID (used as the RevenueCat `app_user_id`), plus the App Store receipt for purchases you make.
- **Data location:** RevenueCat's infrastructure (US).
- **Why:** To validate and track your subscription state on iOS and to deliver subscription-event webhooks to our middleware.
- **Policy:** [revenuecat.com/privacy](https://www.revenuecat.com/privacy/)

### 5.4 Apple App Store

- **What they receive:** Payment details for in-app purchases. We never see your card data.
- **Why:** Process subscription payments. Handle refunds.
- **Policy:** [apple.com/legal/privacy](https://www.apple.com/legal/privacy/)

### 5.5 Firebase (Analytics, Crashlytics, Cloud Messaging)

- **What they receive:** Anonymized usage events (event names, screen names), crash stack traces, device metadata, FCM device token.
- **Data location:** Google Firebase infrastructure.
- **Why:** Product analytics, crash diagnostics, push-notification delivery.
- **Filtering:** Form content, question text, and response content are explicitly stripped before any event is sent. Crashlytics receives a hashed user identifier, not your raw email.
- **Policy:** [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy)

### 5.6 Google Cloud Pub/Sub (push-notification routing)

- **What they receive:** Notifications from Google Forms when one of your forms receives a new response — these contain the form's ID and a timestamp, **not the response content**.
- **Data location:** Google Cloud (US).
- **Why:** Forms emits response-received events through Pub/Sub; our middleware subscribes and fans out to FCM.
- **Policy:** [policies.google.com/privacy](https://policies.google.com/privacy)

### 5.7 Our middleware (`gfm.alphaiit.com`)

- **What it stores about you (persistent):** Your Google account ID + email, your subscription / premium status, and your quota balance. That's it.
- **What it handles operationally (transient or feature-specific):** As listed in §3.2 — FCM device token (only if you grant notification permission), Forms-watch registrations (only on forms you opt in, 7-day TTL from Google), AI request fingerprint and draft response (≤ 60-day TTL, for idempotency), RevenueCat event audit log, Apple subscription binding (anti-abuse).
- **What it does NOT store:** Google Forms content, response data, raw AI prompt text after the request completes, uploaded PDF bytes, payment-card data.
- **Hosting:** A virtual server operated by AlphaIIT.
- **Encryption:** TLS in transit. Data at rest is on encrypted disk.

### 5.8 Sentry (error tracking, server-side)

- **What they receive:** Error stack traces from our middleware, request IDs, the internal numeric user ID associated with the request.
- **Data location:** Sentry's infrastructure.
- **Why:** Diagnose server-side errors.
- **Policy:** [sentry.io/privacy](https://sentry.io/privacy/)

---

## 6. Where your data is processed

Most of our processors operate globally. By using GFM you understand that your data may be transferred to and processed in countries other than yours (notably the United States and the European Union) which may have different data-protection laws than Bangladesh.

Our middleware operates from a server in the United States. We use providers (Google, Apple, RevenueCat, Firebase, Sentry) that publish their own data-processing terms and are widely used by mobile apps worldwide.

---

## 7. How long we keep your data

| Data | Retention |
|---|---|
| Google account ID + email | Until you request deletion (§9) |
| Subscription / premium status | Until you request deletion |
| Quota balance | Until you request deletion. Quota credits, once granted to your account (whether by free monthly grant or by subscription credit), do not expire on a deadline — they remain available until you spend them. |
| AI request fingerprint + draft response | At most 60 days, then automatically purged |
| RevenueCat event audit log | Indefinite — minimal data per event (immutable audit trail) |
| FCM device tokens | Until invalidated or you sign out / uninstall |
| Forms-watch registrations | Auto-expire after 7 days (Google's limit); recreated if you re-enable |
| Firebase Analytics events | Per Firebase's default retention settings (currently 14 months) |
| Crashlytics reports | Per Firebase's default retention settings |
| Website contact-form messages | Until your issue is resolved + a reasonable archival period |

### Quota expiry policy

To be explicit: **quota credits do not expire**. The free tier provides **3 AI generations per month** (granted automatically when due). Subscription tiers credit additional quota when each billing period begins (see Terms §7). Once credited, those credits remain in your balance until you use them — they are not consumed by the passage of time and they are not zeroed at the end of a month or billing period.

---

## 8. Your rights

Subject to applicable law, you have the right to:

- **Access** the personal data we hold about you.
- **Correct** inaccuracies in that data.
- **Delete** your data (subject to legal retention requirements — see §9).
- **Object** to or restrict certain processing.
- **Portability** — receive a copy of the data you provided to us in a machine-readable format.
- **Withdraw consent** at any time where processing is based on consent.
- **Lodge a complaint** with your local data-protection authority.

To exercise any of these rights, email [formmanager000@gmail.com](mailto:formmanager000@gmail.com). We respond within 30 days.

---

## 9. Account deletion

To delete your GFM account and all middleware-side data tied to it, open the app drawer and select **Delete Account**, then confirm by typing `DELETE`. Your account is scheduled for permanent erasure **30 days** after the request. Signing back in to the app at any point during that 30-day window cancels the deletion automatically — no separate action required. If you can no longer access the app, email [formmanager000@gmail.com](mailto:formmanager000@gmail.com) from the address associated with your Google account and we will process the request manually.

Deletion covers:

- Your account record (Google sub + email) and quota state in our middleware.
- AI generation audit rows tied to your account.
- FCM device tokens tied to your account.
- Forms-watch registrations tied to your account.
- Apple subscription binding.

Deletion does **not** cover (these live outside our control):

- Your Google Forms and Drive files — you delete those in Google Drive directly.
- Your Google Sign-In authorization — revoke at [myaccount.google.com](https://myaccount.google.com) → Security → Third-party apps.
- Your active App Store subscription — manage and cancel inside the App Store.
- RevenueCat's immutable webhook event log — minimal, audit-only.
- Firebase Analytics / Crashlytics historical records — subject to Firebase's retention.

After deletion, if you sign in again with the same Google account, a new account record is created — the old one is not recoverable.

---

## 10. Children

GFM is intended for users **aged 13 and over**. We do not knowingly collect personal information from children under 13. In jurisdictions where the minimum age for data processing without parental consent is higher (e.g. 16 under GDPR-K), the higher local minimum applies.

When teachers use GFM to collect responses from students, those responses are stored within the **teacher's** Google account — we do not receive, store, or process student response data.

If you believe a child has provided personal information through GFM, contact [formmanager000@gmail.com](mailto:formmanager000@gmail.com) and we will delete it.

---

## 11. Cookies and similar technologies

- The **app** itself does not use cookies. It uses native secure storage on your device for the Google sign-in session.
- The **website** at `gfm.alphaiit.com` is static and does not set cookies, run analytics, or use trackers. Standard server logs (IP, user agent, timestamp) may be retained for short periods for security and debugging.
- The **middleware** receives requests from the app over TLS with a bearer auth header. No cookies.

---

## 12. Security

We protect your data with:

- TLS for all network traffic between app, middleware, and processors.
- Encrypted-at-rest storage on the middleware database.
- Minimum-necessary OAuth scopes (`drive.file`, not full Drive access).
- Constant-time bearer-secret checks on inbound webhook routes.
- No logging of form content, question text, or response content.

No system is perfectly secure. If we discover a breach affecting your data, we will notify affected users by email within the timelines required by applicable law.

---

## 13. International users

GFM is available worldwide on the Apple App Store. By using GFM you consent to your data being processed in the locations described in §6, including outside your country of residence.

For users in the European Economic Area, the United Kingdom, and Switzerland, §14 below provides the GDPR-specific disclosures. For users in California, §15 provides the CCPA / CPRA disclosures.

---

## 14. European Economic Area, United Kingdom, and Switzerland (GDPR / UK GDPR / FADP)

If you are in the EEA, the UK, or Switzerland, the following supplements this policy.

### 14.1 Data controller

**AlphaIIT** (an independent software developer based in Bangladesh) is the data controller for personal data processed about you through GFM, as described in §§ 3 and 5.

For data processed *inside your forms* (questions you author and responses your respondents submit), **you are the controller** and Google is your processor under your Google Workspace / consumer agreement with Google. We do not receive that data.

We have not appointed an EU representative under Article 27 GDPR at this time. For data-protection inquiries, contact us at [formmanager000@gmail.com](mailto:formmanager000@gmail.com).

### 14.2 Lawful bases for processing (Article 6)

| Purpose | Lawful basis |
|---|---|
| Verify your identity on sign-in and serve API requests on your behalf | **Contract** (Art. 6(1)(b)) — necessary to provide the service you requested |
| Hold your subscription / premium status and quota balance | **Contract** (Art. 6(1)(b)) |
| Process payments via Apple / RevenueCat | **Contract** (Art. 6(1)(b)) |
| Run the AI Form Builder (send your prompt to Gemini, return a draft) | **Contract** (Art. 6(1)(b)) |
| Send push notifications about new responses (only on forms where you enabled the toggle) | **Consent** (Art. 6(1)(a)) — granted when you enable the toggle and respond to the OS-level permission prompt; withdraw any time |
| Anti-abuse: rate-limit, denylist, Apple subscription binding | **Legitimate interests** (Art. 6(1)(f)) — preventing fraud and protecting the service for other users |
| Crash diagnostics (Crashlytics) and anonymized usage analytics (Firebase Analytics) | **Legitimate interests** (Art. 6(1)(f)) — improving product reliability; we use minimal data and exclude form content |
| Reply to support emails | **Legitimate interests** (Art. 6(1)(f)) — necessary to respond to your inquiry |

We do not process **special categories** of personal data (Art. 9). We do not engage in **automated decision-making with legal or similarly significant effects** (Art. 22). The AI Form Builder generates draft forms based on your input, which you review and accept before any form is created; this is not automated decision-making about you.

### 14.3 Your rights under GDPR / UK GDPR

In addition to the rights in §8 above, you have the right to:

- **Access** — receive confirmation of whether we process your personal data and a copy of it.
- **Rectification** — have inaccurate data corrected.
- **Erasure** ("right to be forgotten") — have your data deleted, subject to legal retention requirements.
- **Restriction** — restrict our processing of your data in specified circumstances.
- **Portability** — receive a copy of the data you provided to us in a structured, machine-readable format and have it transmitted to another controller where technically feasible.
- **Object** — object to processing based on legitimate interests, including direct marketing (we do no direct marketing).
- **Withdraw consent** — at any time, where processing is based on consent (e.g. push notifications). Withdrawal does not affect the lawfulness of processing before withdrawal.

To exercise these rights, email [formmanager000@gmail.com](mailto:formmanager000@gmail.com). We respond within 30 days (extendable by a further two months for complex requests, in which case we will inform you).

### 14.4 International data transfers

Our middleware operates from a server in the United States, and the processors we rely on (Google APIs, Gemini, RevenueCat, Apple, Firebase, Sentry) are also primarily headquartered in the United States. Transfers of personal data from the EEA / UK / Switzerland to the United States are protected by:

- **Standard Contractual Clauses (SCCs)** approved by the European Commission, where required.
- **Adequacy decisions** for processors that participate in the EU–US Data Privacy Framework or equivalent.

You can request a copy of the transfer safeguards by emailing us.

### 14.5 Right to lodge a complaint

You have the right to lodge a complaint with the data-protection authority in the EU / UK / Swiss country where you live, work, or where the alleged infringement took place. Contact details: [edpb.europa.eu/about-edpb/about-edpb/members_en](https://edpb.europa.eu/about-edpb/about-edpb/members_en) (EU); [ico.org.uk](https://ico.org.uk) (UK); [edoeb.admin.ch](https://www.edoeb.admin.ch) (Switzerland).

---

## 15. California residents (CCPA / CPRA)

If you are a California resident, the following supplements this policy.

### 15.1 Categories of personal information collected

In the 12 months preceding the effective date, we collect the following categories of personal information as defined under California Civil Code §1798.140:

| CCPA category | Examples collected by GFM | Source | Purpose |
|---|---|---|---|
| **Identifiers** | Google account ID (sub), email address | You, when you sign in | Auth, account management |
| **Commercial information** | Subscription product, quota balance, transaction log | You + Apple/RevenueCat | Provide and bill the service |
| **Internet or network activity** | App event names, screen names, anonymized usage events; crash reports | Your device | Product analytics, crash diagnostics |
| **Geolocation data** | Approximate location inferred from IP only (for security logs) | Network | Security and abuse detection |
| **Inferences** | None | — | — |

We do **not** collect categories of *sensitive personal information* (driver's license, financial-account access credentials, precise geolocation, racial/ethnic origin, religious beliefs, health, sexual orientation, biometrics, etc.).

We do **not** collect personal information of California residents under 16 without consent (and we do not knowingly collect data of users under 13 — see §10).

### 15.2 Sources of personal information

- Directly from you (sign-in, in-app interactions, contact form).
- Automatically from your device (FCM token, crash stack traces, anonymized usage events).
- From third parties processing payments on our behalf (Apple, RevenueCat — for subscription status only).

### 15.3 Business purposes for collection

- Auth and identity verification.
- Provide and bill the subscription service.
- Anti-abuse, rate-limiting, fraud prevention.
- Crash diagnostics and anonymized product analytics.
- Customer support.

### 15.4 Categories of third parties with whom we share personal information

Only the processors listed in §5 — for the purposes described there. We share information with them strictly to deliver the service.

### 15.5 No sale, no sharing for cross-context behavioral advertising

We do **not** sell your personal information and we do **not** share your personal information for cross-context behavioral advertising as those terms are defined under the CPRA. We have not done so in the past 12 months and we have no plans to do so. Because we do not sell or share, we do not provide a "Do Not Sell or Share My Personal Information" link — there is nothing to opt out of.

### 15.6 Your California rights

Subject to verification, California residents have the right to:

- **Know** what categories and specific pieces of personal information we have collected about you, the categories of sources, the business purposes, and the categories of third parties with whom we shared it.
- **Delete** your personal information, subject to applicable exceptions.
- **Correct** inaccurate personal information.
- **Limit use** of sensitive personal information (not applicable — we do not collect sensitive PI).
- **Opt out** of sale or cross-context behavioral advertising (not applicable — we do neither).
- **Non-discrimination** for exercising any of these rights.

### 15.7 How to exercise your rights

Email [formmanager000@gmail.com](mailto:formmanager000@gmail.com) from the address associated with your Google account, or include enough information to allow us to verify your identity. We respond within 45 days (extendable by 45 days with notice). Authorized agents may submit requests on your behalf; we will ask for a written authorization signed by you.

---

## 16. Changes to this policy

We may update this Privacy Policy from time to time. The current version is always available at [gfm.alphaiit.com/privacy.html](https://gfm.alphaiit.com/privacy.html). For material changes that affect how we process your data, we will notify you within the app and where appropriate require re-acknowledgement before continued use. Minor clarifications are reflected by updating the "Last updated" date at the top of this document.

---

## 17. Contact

Privacy and legal inquiries — including data-access and deletion requests:

**AlphaIIT — GFM**
Email: [formmanager000@gmail.com](mailto:formmanager000@gmail.com)
Website: [gfm.alphaiit.com](https://gfm.alphaiit.com)

We aim to respond within 5 business days for general inquiries and within 30 days for formal rights requests (45 for California requests).
