# tempo

Personal auto-scheduling planner. Tasks carry a duration and a deadline; the
planner reads your Google Calendar, finds genuinely free gaps, and places the
work into them. When you slip, it re-plans.

Flutter app + Firebase backend + Cloud Functions. Firebase project
`tempo-3ac43`. Own git repo, remote `github.com/nnavnita/tempo`.

> **This repo pivoted.** Tempo was a social calendar (friends, feeds, event
> visibility) until November 2026. That build is preserved at branch
> `archive/social-v1` and tag `archive-social-v1`. None of it is coming back —
> ignore any doc or comment that still describes friends or event sharing.

## Stack

- Flutter (Dart SDK ^3.10.7)
- Firebase: Auth (Google Sign-In), Firestore, Cloud Messaging
- Cloud Functions (Node 20, JavaScript) — `functions/`
- Riverpod (hand-written providers, no codegen), go_router
- Google Calendar API (OAuth via Firebase's auto-created client)
- `timezone` for DST-correct planning, `flutter_local_notifications`

## The design in one page

Four ways a task gets missed — never captured, captured but buried, never
given time, reminded at a useless moment. They are a chain, so v1 is a thin
vertical slice through all four rather than one of them built deep.

Full spec: `docs/superpowers/specs/2026-11-06-tempo-planner-design.md`.

Non-negotiables, all with tests pinning them:

- **No task is ever silently dropped.** After a plan run every task is in
  exactly one visible state. "Unplaceable" is explicit and says *why*.
- **Slip recovery ships.** A missed slot returns the task to the pool and
  bumps `slipCount`. At 3 it becomes `slipped` (stuck) and demands user
  triage — it is never auto-requeued forever. This is the anti-graveyard
  mechanism and the reason the product exists.
- **The solver is pure.** No clock, no Firestore, no I/O. That is what makes
  the DST, saturation and chunk-floor cases testable at all.
- **Degraded planning is visible.** Calendar down means planning from cache
  plus a banner. Planning against an empty calendar would book over every
  real commitment.

## Layout

```
lib/
├── main.dart                       Firebase + timezone init, notification init
├── config/providers/               Riverpod wiring (hand-written)
├── config/router/                  go_router + bottom nav shell
├── models/                         task, scheduled_slot, plan_state, working_hours
├── services/scheduler/             the core
│   ├── time_interval.dart            half-open intervals, merge, subtract
│   ├── free_gap_extractor.dart       calendar + working hours → free gaps
│   ├── placement_solver.dart         PURE. EDF greedy. Keep it pure.
│   └── plan_writer.dart              orchestration: read → solve → persist
├── services/calendar/              busy_interval_source (the seam), Google client
├── services/firestore/             task, slot, plan_state, busy_cache repos
├── services/notifications/         local slot scheduler, FCM replan listener
└── features/{auth,capture,plan,triage,profile}/
functions/                          slip detection + re-plan push
```

## Key flows

**Capture → plan.** `CaptureScreen` → `PlanController.addTask` →
`PlanWriter.replan`: fetch busy from Calendar (refreshing `busyCache`), carve
free gaps in the user's local zone, `solvePlacements`, write slots and task
statuses, bump `planVersion`, re-register local notifications.

**Slip → re-plan.** The `detectSlips` function sweeps every 30 minutes for
slots whose window closed undone, marks them `missed`, bumps `slipCount`, and
pushes `type: replan_required`. The client re-plans on receipt or next
foreground.

> The function deliberately does **not** re-place work. Placement has one
> implementation — the Dart solver — and porting it to JavaScript would
> guarantee drift. The server does the part the client cannot: authoritative
> slip bookkeeping while the app is closed.

`STUCK_SLIP_THRESHOLD` in `functions/slip.js` and
`TaskModel.stuckSlipThreshold` are a contract. Change one, change the other;
a test asserts they agree.

## Gotchas worth knowing before you touch things

- **iOS caps pending local notifications at 64** and silently drops the rest,
  which is why `AppConstants.localNotificationHorizon` is 20 and why
  re-planning is server-triggered at all.
- **Slot ids are deterministic** (`taskId_startMillis`). `replaceFuturePlan`
  therefore diffs by id rather than deleting and re-setting — two writes to
  one document in a batch have backend-dependent ordering, and that bug ate
  slots.
- **Gap extraction walks *local* days**, not UTC days. Iterating UTC drifts
  the working window by an hour either side of a DST transition.
- **The planning time zone is pinned** to `AppConstants.fallbackTimeZone`.
  Reading the device IANA zone needs a platform channel. Anyone outside
  Melbourne currently gets wrong working hours.
- `freezed` and `json_serializable` are in `pubspec.yaml` but unused. Models
  are plain classes with `fromFirestore`/`toMap`. Keep it that way.

## Setup

`SETUP.md` has the full walkthrough. Release steps and everything that needs
Navnita's Apple/Google credentials: `docs/release/release-checklist.md`.

## Testing

```bash
flutter analyze && flutter test     # 66 tests
cd functions && node --test         # 6 tests
```

The solver tests are the ones that matter. If you change placement, the
golden scenarios in `test/services/scheduler/placement_solver_test.dart`
(empty, saturated, deadline collisions, three-way chunking, chunk floor, DST,
determinism) are the specification.

## Roadmap

`bullseye.yaml` — managed by the bullseye MCP server. Use `bullseye_frontier`
(cwd = this repo) for what's next.
