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

The required composite indexes live in `firestore.indexes.json` and deploy
with the rules in the previous step. They cover the elapsed-slot query used
by slip detection, in both collection and collection-group scope — the
client reads one user's slots, the Cloud Function sweeps across all users.

```bash
firebase deploy --only firestore:indexes
```

Firestore will also prompt you with a one-click creation link in the error
message if a query ever needs an index that is missing.

---

## 9. Run the App

```bash
flutter run
```

---

## 10. Deploy Cloud Functions

Slip detection runs as a scheduled function, which requires the **Blaze**
plan — scheduled functions are not available on Spark.

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Verify it registered:

```bash
firebase functions:log --only detectSlips
```

---

## Architecture Overview

```
lib/
├── main.dart                       Firebase + timezone init, notification init
├── config/providers/               Riverpod wiring (hand-written, no codegen)
├── config/router/                  go_router + bottom nav shell
├── models/                         task, scheduled_slot, plan_state, working_hours
├── services/scheduler/
│   ├── time_interval.dart            half-open intervals, merge, subtract
│   ├── free_gap_extractor.dart       calendar + working hours → free gaps
│   ├── placement_solver.dart         pure EDF greedy placement
│   └── plan_writer.dart              orchestration: read → solve → persist
├── services/calendar/              busy_interval_source, Google Calendar client
├── services/firestore/             task, slot, plan_state, busy_cache repos
├── services/notifications/         local slot scheduler, FCM replan listener
└── features/{auth,capture,plan,triage,profile}/
functions/                          slip detection + re-plan push (Node 20)
```

### Firestore layout

Everything is user-scoped. There are no cross-user reads, which is why the
security rules are a single owner check throughout.

```
users/{uid}
├── (profile: displayName, email, photoURL, fcmToken)
├── tasks/{taskId}        title, durationMinutes, deadline, priority,
│                         status, splittable, minChunkMinutes, slipCount
├── slots/{slotId}        taskId, start, end, state, planVersion
│                         slotId = "{taskId}_{startMillis}" — deterministic
├── planState/current     planVersion, generatedAt, horizon, lastReplanReason
└── busyCache/{dayKey}    cached calendar busy intervals, "YYYY-MM-DD" local
```

---

## Key Flows

### Capturing a task

1. `CaptureScreen` collects title, duration, optional deadline and priority.
   Duration is mandatory — a task with no time cost cannot be fitted against
   a calendar, which is why plain lists never become plans.
2. `PlanController.addTask` writes the task, then immediately re-plans.

### Planning

`PlanWriter.replan` is the only place that knows the order of operations:

1. Fetch busy intervals from Google Calendar for the next 14 days, and
   refresh `busyCache`. If the Calendar API fails, fall back to the cache and
   set `usedCachedCalendar` so the UI can show the degraded banner.
2. `extractFreeGaps` subtracts busy time from the working window, walking
   **local** calendar days so DST transitions do not shift the window.
3. `solvePlacements` places tasks earliest-deadline-first, first-fit, with
   chunking for splittable tasks. Pure function — no clock, no I/O.
4. Write slots via `replaceFuturePlan`, which diffs by slot id. Past slots
   are left alone; they are the record of what happened.
5. Apply task statuses — `scheduled`, `unplaceable` or `overdue`. Every
   plannable task gets exactly one visible status.
6. Bump `planVersion`, then re-register local notifications.

### Slip recovery

1. The `detectSlips` function sweeps every 30 minutes for slots whose window
   closed while still `planned`, `notified` or `started`.
2. Those slots become `missed`; their tasks return to `inbox` with
   `slipCount` incremented.
3. At `slipCount >= 3` the task becomes `slipped` — stuck — and stops being
   auto-placed. It waits in Triage for the user to shrink, drop or
   hand-schedule it.
4. The function pushes `type: replan_required`; the client re-plans on
   receipt or next foreground.

The function does not re-place work. Placement has one implementation, and
duplicating it in JavaScript would guarantee drift.

### Notification delivery

Only the next 20 slots are registered with the OS. iOS caps pending local
notifications at 64 per app and silently drops the overflow, so the client
holds the near horizon and the server covers the rest by push.

---

## Testing

```bash
flutter analyze
flutter test              # 66 tests
cd functions && node --test   # 6 tests
```

The solver's golden scenarios in
`test/services/scheduler/placement_solver_test.dart` are the specification
for placement behaviour: empty and saturated calendars, deadline collisions,
three-way chunking, the chunk floor, DST, and run-to-run determinism.

---

## Releasing

See `docs/release/release-checklist.md`. It separates what is already wired
in the repo from what needs the account holder's Apple and Google
credentials.
