# Tempo — Setup Guide

## Prerequisites
- Flutter 3.x SDK
- Node.js (for Firebase CLI)
- A Google Cloud / Firebase project
- Xcode (for iOS) + Android Studio (for Android)

---

## 1. Firebase Project Setup

### Create a Firebase project
1. Go to https://console.firebase.google.com
2. Create a new project named **tempo**

### Enable services
- **Authentication** → Sign-in method → Enable **Google**
- **Firestore Database** → Create in production mode
- **Cloud Messaging** (optional, for push notifications)

---

## 2. Enable Google Calendar API

1. Go to https://console.cloud.google.com → Select your Firebase project
2. APIs & Services → Library → search **Google Calendar API** → Enable it
3. APIs & Services → OAuth consent screen → fill out the form
4. The OAuth client ID is already created by Firebase for your app — no additional setup needed for mobile apps using Google Sign-In

---

## 3. FlutterFire CLI Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# In the project root:
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `lib/firebase_options.dart`. Then uncomment the two lines in `lib/main.dart`:
```dart
import 'firebase_options.dart';
// ...
options: DefaultFirebaseOptions.currentPlatform,
```

---

## 4. Android Configuration

### SHA-1 fingerprint
Firebase Google Sign-In requires your app's SHA-1:
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
Add the SHA-1 in Firebase Console → Project Settings → Your Android app → Add fingerprint.

### Download `google-services.json`
Firebase Console → Project Settings → Android → Download `google-services.json`
Place it in `android/app/google-services.json`.

### `android/app/build.gradle`
Ensure you have:
```gradle
defaultConfig {
    minSdkVersion 21   // Required for Firebase
}
```

---

## 5. iOS Configuration

### Download `GoogleService-Info.plist`
Firebase Console → Project Settings → iOS → Download `GoogleService-Info.plist`
Add it to `ios/Runner/GoogleService-Info.plist` via Xcode (drag & drop).

### URL Scheme
Add the **REVERSED_CLIENT_ID** from `GoogleService-Info.plist` as a URL scheme in Xcode:
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner target → Info → URL Types → Add item
- URL Schemes: paste the REVERSED_CLIENT_ID value

### `ios/Podfile`
Set minimum iOS version:
```ruby
platform :ios, '13.0'
```

---

## 6. Install Dependencies

```bash
flutter pub get
```

---

## 7. Deploy Firestore Rules

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Initialize (select Firestore)
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

---

## 8. Create Firestore Indexes

These composite indexes are required. Create them in Firebase Console → Firestore → Indexes → Composite:

| Collection    | Fields                                          |
|---------------|-------------------------------------------------|
| `events`      | `ownerUid` ASC, `startTime` ASC                 |
| `events`      | `ownerUid` ASC, `visibility` ASC, `startTime` ASC |
| `events`      | `ownerUid` ASC, `visibility` ASC, `startTime` ASC (for feed with whereIn) |
| `busy_slots`  | `ownerUid` ASC, `startTime` ASC                 |
| `join_requests` | `eventOwnerUid` ASC, `status` ASC, `requestedAt` DESC |
| `invitations` | `inviteeUid` ASC, `status` ASC, `sentAt` DESC   |
| `friendships` | `users` ARRAY, `status` ASC                     |

Firestore will also prompt you to create indexes automatically when queries fail with a link in the error message — click that link for one-click creation.

---

## 9. Run the App

```bash
flutter run
```

---

## Architecture Overview

```
lib/
├── main.dart                          # App entry, Firebase init, ProviderScope
├── config/
│   ├── providers/firebase_providers.dart   # All Riverpod service providers
│   └── router/app_router.dart              # go_router config + bottom nav shell
├── core/
│   ├── constants/                     # App, Firestore, Route constants
│   └── theme/                         # AppTheme, AppColors
├── models/                            # Firestore data models
├── services/
│   ├── auth/                          # AuthService, AuthTokenService
│   ├── calendar/                      # GoogleCalendarService, CalendarSyncService
│   └── firestore/                     # Repository classes
├── providers/                         # Riverpod stream/future providers
└── features/
    ├── auth/                          # Login screen
    ├── calendar/                      # Main calendar view
    ├── events/                        # Create/Edit/Detail screens
    ├── friends/                       # Friends list, requests, search
    ├── feed/                          # Public events feed
    ├── notifications/                 # Invitations + join requests inbox
    └── profile/                       # Profile + sign out
```

## Key Flows

### Creating an event
1. `CreateEventScreen` → `CalendarSyncService.createEvent()`
2. Writes to Firestore `events` collection
3. Inserts into Google Calendar via `GoogleCalendarService`
4. If private: writes a `busy_slot` document (no title/description, just times)
5. Sends invitations to selected friends via `InvitationRepository`

### Join request flow
1. User sees event on Feed/EventDetail → taps "Request to Join"
2. `JoinRequestRepository.createRequest()` creates a Firestore document
3. Owner sees it in Notifications screen → approves/denies
4. On approval: `CalendarSyncService.addAttendeeToEvent()` adds to attendee's Google Calendar + updates `attendeeUids`

### Invitation flow
1. Owner selects friends in `CreateEventScreen` or `EditEventScreen`
2. `InvitationRepository.createInvitation()` per invitee
3. Invitee sees it in Notifications → accepts/rejects
4. On accept: event added to their Google Calendar via `CalendarSyncService`

### Privacy model
- **Private**: Only owner can read the `events` doc. A `busy_slot` doc (no detail) lets others see the time is blocked.
- **Friends**: Readable by accepted friends only (enforced by Firestore security rules via `areFriends()` helper).
- **Everyone**: Readable by any authenticated user.
