# tempo

Social calendar and smart task scheduler. Flutter app + Firebase backend, Google Calendar sync, friends/events/join-requests with a privacy model (private / friends / everyone).

Own git repo, remote `github.com/nnavnita/tempo`, tracking `origin/main`.

## Stack

- Flutter (Dart SDK ^3.10.7)
- Firebase: Auth (Google Sign-In), Firestore, Cloud Messaging
- Riverpod (state/providers), go_router (routing)
- Google Calendar API (OAuth via Firebase's auto-created client)

## Setup

Full walkthrough in `SETUP.md` — summary:

1. Create a Firebase project named `tempo`; enable Authentication (Google), Firestore (production mode), Cloud Messaging (optional).
2. Enable the Google Calendar API in the same GCP project; fill out the OAuth consent screen.
3. `dart pub global activate flutterfire_cli` then `flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID` — generates `lib/firebase_options.dart`.
4. Android: add SHA-1 (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`) to Firebase console, download `google-services.json` into `android/app/`.
5. iOS: download `GoogleService-Info.plist` into `ios/Runner/`, add its `REVERSED_CLIENT_ID` as a URL scheme in Xcode, set `platform :ios, '13.0'` in `ios/Podfile`.
6. `flutter pub get`
7. `firebase deploy --only firestore:rules` (needs `npm install -g firebase-tools && firebase login`)
8. Create the composite Firestore indexes listed in `SETUP.md` (or click the auto-generated link when a query fails).
9. `flutter run`

## Layout

```
lib/
├── main.dart                  Firebase init, ProviderScope
├── config/providers/          Riverpod service providers
├── config/router/             go_router + bottom nav shell
├── models/                    Firestore data models
├── services/{auth,calendar,firestore}/
├── providers/                 Riverpod stream/future providers
└── features/{auth,calendar,events,friends,feed,notifications,profile}/
```

## Key flows

Documented in detail in `SETUP.md` under "Key Flows": event creation → Firestore write → Google Calendar insert (+ busy_slot if private) → invitations; join-request approve/deny; invitation accept/reject. Privacy enforced by Firestore security rules (`areFriends()` helper), not just client-side filtering.

## Roadmap

`bullseye.yaml` — managed by the bullseye MCP server. Use `bullseye_frontier` (cwd = this repo) for what's next.
