# Mailflow — Flutter Email Client

A mobile email client built with Flutter that connects to real Gmail accounts via Google OAuth 2.0 and the Gmail REST API.

---

## Prerequisites

- Flutter 3.41.6 (stable channel) — run `flutter --version` to check
- Dart 3.11.4
- Android SDK with `minSdk 21+` or Xcode 14+ for iOS
- A Google account with Gmail enabled
- A Google Cloud project with the Gmail API enabled

---

## Getting Started

### 1. Clone and install

```bash
git clone https://github.com/eshanokpe/flutter_email_client.git
cd flutter_email_client
flutter pub get
```

### 2. Google Cloud setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and create a project
2. Enable the **Gmail API** under APIs & Services
3. Configure the **OAuth consent screen** — set scope to `https://mail.google.com/`
4. Add your Gmail address as a **test user**
5. Create OAuth credentials for **Android** and **iOS** separately

### 3. Android config

- Download `google-services.json` from the credentials page
- Place it at `android/app/google-services.json`

### 4. iOS config

- Download `GoogleService-Info.plist` from the credentials page
- Add it to `ios/Runner/` via Xcode (File → Add Files to Runner)
- Add the `REVERSED_CLIENT_ID` URL scheme to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### 5. Run

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Release build
flutter build apk --release
flutter build ios --release
```

---

## Features

- **Google Sign-In** — OAuth 2.0, no passwords stored
- **Inbox** — real emails fetched from Gmail API with pull-to-refresh
- **Email detail** — full body, read/unread toggle, star, reply
- **Compose** — send emails via Gmail API with validation
- **Folder navigation** — Inbox, Sent, Drafts, Starred, Trash, Spam
- **Search** — real-time client-side filtering
- **Swipe actions** — swipe to delete or star
- **Session restore** — stays signed in across app restarts

---

## Project Structure

```
lib/
├── core/
│   ├── constants/        # Routes, folder names, UI constants
│   └── theme/            # Light theme — colors, typography
├── data/
│   ├── models/           # EmailModel, EmailConfig
│   ├── repositories/     # EmailRepository, AuthRepository
│   └── services/         # GmailService, CredentialStorage
└── presentation/
    ├── providers/         # Riverpod state + GoRouter
    └── screens/           # Login, Inbox, Detail, Compose
    └── widgets/           # Avatar widget
```

**Stack:** Flutter · Riverpod · GoRouter · Gmail REST API · google_sign_in · flutter_secure_storage

---

## Challenges

**1. Gmail requires OAuth, not passwords**
Raw IMAP/SMTP was the initial approach but Gmail blocks password-based login by default. Switched to the Gmail REST API with OAuth 2.0 via `google_sign_in` — this is actually cleaner since it avoids storing credentials entirely and handles token refresh automatically.

**2. Gmail message ID encoding**
The Gmail API returns message IDs that needed to be preserved exactly for subsequent API calls (flag updates, delete, fetch body). Added a composite ID format (`gmailId-uuid`) so the UI has a unique key per message while the service can always extract the original Gmail ID for API calls.

**3. Multipart email body extraction**
Gmail messages arrive as nested MIME parts — `multipart/alternative` wrapping `text/plain` and `text/html`, sometimes several levels deep. Built a recursive `_extractBody()` method that walks the part tree and prefers `text/plain` over `text/html`, falling back to the snippet when no body parts are found.

**4. RFC 2822 date parsing**
Email date headers follow the format `Mon, 01 Jan 2024 12:00:00 +0000` which `DateTime.parse()` does not handle. Added a fallback that strips the weekday prefix before attempting a second parse.

**5. iOS URL scheme for OAuth redirect**
The Google sign-in sheet on iOS opened correctly but hung on redirect until the `REVERSED_CLIENT_ID` URL scheme was registered in `Info.plist`. Without it the OS has no way to hand control back to the app after the browser-based auth flow completes.

---

## Notes

- The app is registered as an **External** OAuth app in test mode — only Gmail addresses added as test users (https://console.cloud.google.com/auth/audience?project=mailflow-492416) in the Google Cloud Console can sign in
- To open the app to all users, submit for Google OAuth verification


`
