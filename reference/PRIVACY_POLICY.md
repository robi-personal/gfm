# Privacy Policy

**Effective Date:** {{EFFECTIVE_DATE}}
**Last Updated:** {{LAST_UPDATED_DATE}}

> **Note for Claude Code / maintainers:** Replace the four placeholders before publishing: `{{EFFECTIVE_DATE}}`, `{{LAST_UPDATED_DATE}}`, `{{LEGAL_NAME}}`, `{{JURISDICTION}}`. The policy is otherwise final — do not edit wording without a legal review, since this text is what Google OAuth verification compares against in-app behavior.

---

## 1. Who we are

This Privacy Policy describes how ("we", "our", "us") processes information in connection with our application **GFM — Google Forms Manager** ("GFM", "the app").

- Website: netlify.gfm.com
- Contact: formmanager000@gmail.com

This policy applies to GFM and any future products published under the same identity at netlify.gfm.com.

---

## 2. What GFM is

GFM is a mobile client application that interacts directly with Google APIs (Google Forms API and Google Drive API) on behalf of the signed-in user.

GFM does not operate a backend server for storing user-generated form content. All form structures, questions, settings, and responses remain within the user's own Google account. The application uses Firebase services for crash reporting and aggregate usage analytics, as detailed in §8.

---

## 3. Google API Services User Data Policy — Limited Use compliance

GFM's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

Specifically, we affirm:

- We use Google user data **only to provide and improve user-facing features** within GFM.
- We do **not** sell Google user data.
- We do **not** use Google user data for advertising purposes.
- We do **not** use Google user data to build user profiles or to train AI/ML models.
- We do **not** transfer Google user data to third parties, except:
  - to Google services as required for the application to function, or
  - as required by law.
- We do **not** allow humans to read Google user data, except:
  - with the user's explicit consent for support or troubleshooting,
  - for security investigations, or
  - to comply with applicable law.

---

## 4. Data storage and on-device caching

We do not store, log, or persist Google user data on our servers.

To enable offline editing and a responsive user experience, GFM may temporarily cache form content on the user's device. This local cache:

- is private to the user's device,
- is encrypted at rest where supported by the operating system (Android Keystore, iOS Keychain),
- is cleared automatically on sign-out or app uninstall,
- is never transmitted to external servers or to any third party other than Google APIs.

---

## 5. Google API scopes and why we need them

GFM requests the minimum set of OAuth scopes required for its functionality:

### `https://www.googleapis.com/auth/drive.file`

Used to:
- Create new Google Forms in the user's Drive.
- Open, modify, and delete forms the user creates within GFM or explicitly opens by pasting a link.
- Upload images that the user chooses to embed in their forms.

This scope restricts GFM to files the app itself created or that the user explicitly opened. GFM cannot see other files in the user's Drive.

### `https://www.googleapis.com/auth/forms.body`

Used to:
- Create form titles, descriptions, and settings.
- Add, edit, reorder, and delete questions, sections, and media items.
- Configure quiz settings, grading, and form publish state.

### `https://www.googleapis.com/auth/forms.responses.readonly`

Used to:
- Display response counts and individual responses to the signed-in user, for forms they have access to.
- Power the in-app "Responses" view and CSV/Excel export of responses (paid feature).

This scope is necessary because the Forms API does not expose response counts or response content through any other mechanism. Without it, users would have to leave the app and open a browser to see whether anyone has answered their forms — which defeats the core value of a mobile-first companion. Access occurs only during active user interaction. We do not perform background polling, bulk extraction, or external processing of response data.

---

## 6. Sensitive data in form responses

Form responses may contain personal or sensitive information, depending on what the form creator asks and what respondents choose to share.

GFM enforces:

- No storage of response data on external servers.
- No transmission of response data outside of Google APIs and the user's device.
- No analysis, profiling, or aggregation of response content.

Response data is displayed only to the signed-in Google user who has access to the form.

---

## 7. Authentication and tokens

Authentication uses Google OAuth 2.0 via the official Google Sign-In flow.

- Refresh tokens are stored encrypted on-device using the operating system's secure storage (Android Keystore, iOS Keychain).
- Access tokens are held in memory only during an active session.
- All tokens are deleted from the device when the user signs out, uninstalls the app, or revokes access from their Google Account.

We never transmit OAuth tokens to external servers or to any third party other than Google.

---

## 8. Analytics and crash reporting

GFM uses two Firebase services from Google to maintain app quality:

- **Firebase Analytics** — to understand aggregate, anonymous usage patterns (which screens are visited, which features are used).
- **Firebase Crashlytics** — to receive automated crash reports so we can fix bugs.

These services may collect:

- Device type, operating system version, app version, language, country.
- Anonymous, randomly-generated installation identifiers.
- IP address (collected by Firebase SDK; used for approximate location and abuse prevention).
- Crash stack traces and the application state at the time of a crash.

We explicitly confirm:

- No form content, question text, response data, or personal user identifiers (including email addresses) are sent to Firebase.
- Crash grouping uses a randomly generated installation ID, not any identifier derived from the user's Google account.
- Firebase data is used strictly to maintain app stability and improve the product. It is never used for advertising, profiling, or sold to third parties.

Firebase data handling is governed by [Google's privacy policies](https://firebase.google.com/support/privacy).

---

## 9. Data retention

- **Google user data:** not retained by any external entity. All form data lives in the user's Google account.
- **On-device cache:** retained until the user signs out, uninstalls the app, or clears app data.
- **Firebase Analytics and Crashlytics:** retained according to Firebase's default retention settings, which are configured and controlled by Google. We do not extend or alter these defaults.

---

## 10. Data deletion and revocation

Users retain full control of their data at all times.

**To revoke GFM's access to your Google account:**
Go to your [Google Account → Security → Third-party apps with account access](https://myaccount.google.com/permissions) and remove GFM. Access is revoked immediately and the app can no longer read or modify your data.

**To delete data created with GFM:**
Forms created in GFM are stored in your Google Drive. Delete them directly from Drive or the Google Forms web interface. GFM does not maintain any independent data store from which separate deletion is needed.

**To clear on-device data:**
Uninstall the app, or use your device's app settings to clear app data.

---

## 11. Data sharing

We do not sell, rent, lease, or share user data with third parties for any purpose other than the service provider relationships described in this policy (Google APIs, Firebase). We do not share data with advertisers. We do not transfer Google user data outside of Google's services.

---

## 12. Uploaded images and link-based access

When a user adds an image to a form through GFM, the image is uploaded to the user's own Google Drive. To make the image visible to form respondents, GFM sets the file's sharing permission to "anyone with the link can view," which is required by the Google Forms API for embedded images to render.

Before any image is uploaded for the first time, GFM displays an in-app confirmation explaining this permission change. Users may decline.

Once a file is set to "anyone with the link," anyone who obtains the link may view the file. Users are responsible for managing the visibility of files they upload and for not embedding sensitive imagery in forms.

---

## 13. Security measures

We implement:

- HTTPS encryption for all network communications.
- OAuth 2.0 authentication via Google's official SDK — GFM never sees the user's Google password.
- On-device encryption of authentication tokens via OS-provided secure storage.
- No storage of Google user data on external infrastructure, eliminating server-side breach risk for that data class.
- Regular updates to the application and its dependencies to address security advisories.

No system is perfectly secure. Users should keep their device operating system and the GFM app up to date.

---

## 14. Children and educational use

GFM is intended for use by adults (typically aged 18 and over), including teachers, administrators, small business owners, and event organizers.

GFM is not directed to children under 13 (or under 16 in jurisdictions where that is the applicable threshold under GDPR-K), and we do not knowingly collect personal information from children through the app.

When teachers use GFM to collect responses from students, those responses are submitted to and stored within the teacher's Google account, governed by Google's terms and the educational institution's policies. We do not receive, store, or process student response data.

If you believe a child has provided personal information through GFM in a way that involves us, please contact formmanager000@gmail.com and we will take appropriate action.

---

## 15. International data transfers

GFM is operated from Bangladesh. Google and Firebase services may process data on servers located in countries other than the user's own, including the United States.

Where required by applicable law (including the EU General Data Protection Regulation), such transfers rely on the legal mechanisms Google maintains for its services, including Standard Contractual Clauses. By using GFM, you acknowledge that data processed by Google APIs and Firebase is handled in accordance with Google's own data transfer frameworks.

---

## 16. Your rights

Depending on your jurisdiction, you may have the right to:

- Access the personal data we hold about you (in our case, none beyond Firebase telemetry tied to a random installation ID).
- Request correction or deletion of your data.
- Withdraw your consent to data processing at any time by revoking the app's Google access (see §10).
- Lodge a complaint with your local data protection authority.

To exercise any of these rights, contact formmanager000@gmail.com.

---

## 17. Changes to this policy

We may update this Privacy Policy from time to time. The current version is always available at:

https://netlify.gfm.com/privacy

For material changes that affect how we process your data, we will notify you within the app and where appropriate require re-acknowledgement before continued use. Minor clarifications or formatting changes will be reflected via an updated "Last Updated" date.

---

## 18. Contact

Email: formmanager000@gmail.com
Website: https://netlify.gfm.com

---

## 19. Governing law

This Privacy Policy is governed by the laws of Bangladesh, without regard to its conflict-of-law provisions.
