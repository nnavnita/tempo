# tempo

A planner that puts your tasks into the actual free gaps in your calendar,
and re-plans when you slip.

## Why

A list tells you what to do. It does not tell you *when*, which is why lists
quietly become graveyards.

Tempo asks one extra question when you add a task — how long will this take —
and then does something with the answer. It reads your Google Calendar, finds
the time you are genuinely free, and places the task there. Your plan is made
of real times.

The part most planners get wrong is what happens when you miss something. A
plan you have fallen behind is a plan that is now wrong, and quietly
rescheduling forever is how an app turns into a source of guilt. Tempo
re-plans when you slip — and after three misses it stops pretending, flags
the task as stuck, and asks you to shrink it, drop it, or schedule it
yourself.

## Principles

- **Nothing is ever silently dropped.** After every plan run each task is in
  exactly one visible state. A task that will not fit says *why* — no gap
  big enough, or no gap left before its deadline.
- **Slip recovery is the product**, not a feature bolted on later.
- **Degraded planning is visible.** If the calendar cannot be reached, Tempo
  plans from cache and says so, rather than booking over your real
  commitments in silence.

## Features

- **Duration-first capture** — tasks carry an estimate, a deadline and a
  priority, because that is what makes them schedulable
- **Automatic placement** — earliest-deadline-first into real free gaps,
  reading busy time from Google Calendar
- **Splittable tasks** — long work chunked across several gaps, never below
  a minimum useful block
- **Slip recovery** — missed blocks are detected server-side even with the
  app closed, then re-planned
- **Triage** — stuck, overdue and unplaceable tasks surface with the actual
  reason, not a shrug
- **Reminders** at the start of each planned block

## Stack

- **Flutter** (Dart) — Android and iOS
- **Firebase** — Auth (Google Sign-In), Firestore, Cloud Messaging
- **Cloud Functions** (Node 20) — slip detection and re-plan pushes
- **Riverpod** — state management, hand-written providers
- **go_router** — routing
- **Google Calendar API** — free/busy via OAuth

## Status

v1 spine is implemented: capture → placement → reminders → slip recovery.
Not yet released to the app stores; see
[`docs/release/release-checklist.md`](docs/release/release-checklist.md).

Planned next: voice and natural-language capture with inferred durations,
smarter resurfacing, and context-aware reminder delivery. See
[`bullseye.yaml`](bullseye.yaml) for the live roadmap.

> Tempo was a social calendar until November 2026. That build is archived at
> tag `archive-social-v1`.

## Getting started

Full walkthrough — Firebase setup, `flutterfire configure`, platform config,
rules and indexes, functions deploy — is in [`SETUP.md`](SETUP.md).

```bash
flutter pub get
flutter run
```

## Project layout

```
lib/
├── main.dart                  Firebase + timezone init
├── config/{providers,router}/ Riverpod wiring, go_router shell
├── models/                    task, scheduled_slot, plan_state, working_hours
├── services/scheduler/        intervals, gap extraction, solver, plan writer
├── services/calendar/         Google Calendar client behind a narrow seam
├── services/firestore/        repositories
├── services/notifications/    local scheduling + FCM
└── features/{auth,capture,plan,triage,profile}/
functions/                     slip detection + re-plan push
```

## Testing

```bash
flutter analyze && flutter test     # 66 tests
cd functions && node --test         # 6 tests
```
