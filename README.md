# tempo

Social calendar and smart task scheduler. Block out time on your calendar and control exactly who sees it — friends, specific friend groups, or the public — then let people request to join, invite them yourself, and keep the whole thing in sync with Google Calendar.

## Why

Most calendar apps are either private-only (Google Calendar) or public-event-only (Meetup, Eventbrite). Tempo sits in between: every event carries its own visibility — private, friends-only, or public — and approving a join request or sending an invite automatically blocks that time out on the other person's calendar too, so plans stay in sync without manual re-entry.

## Features

- **Google Sign-In + Calendar sync** — events created in Tempo are mirrored into your Google Calendar, and vice versa via busy-slot tracking.
- **Visibility tiers** — `private` / `friends` / `everyone` per event, enforced server-side by Firestore security rules, not just hidden in the UI.
- **Friends graph** — send/accept friend requests, browse a friend's public and friends-visible events.
- **Join requests & invitations** — request to join someone else's event, or invite people to yours; approval blocks the time on both calendars.
- **Public feed** — see `everyone`-visibility events from people you follow.
- **Notifications inbox** — friend requests, join requests, and invitations all flow through one place.

## Stack

- **Flutter** (Dart) — Android, iOS, web from one codebase
- **Firebase** — Auth (Google Sign-In), Firestore, Cloud Messaging
- **Riverpod** — state management / providers
- **go_router** — declarative routing
- **Google Calendar API** — two-way event sync via OAuth

## Status

Actively developed. Core MVP (auth, events, calendar sync, friends, join requests, feed, notifications) is implemented; see [`bullseye.yaml`](bullseye.yaml) for the live roadmap of what's built vs. in progress — friend sub-groups and finer-grained per-event visibility (share with a specific group, hide from specific people) are in progress next.

## Getting started

Full setup walkthrough — Firebase project creation, `flutterfire configure`, platform-specific config, Firestore rules/indexes — is in [`SETUP.md`](SETUP.md).

```bash
flutter pub get
flutter run
```

## Project layout

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
