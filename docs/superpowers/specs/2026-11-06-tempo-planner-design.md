# Tempo v2 — Personal Auto-Scheduling Planner

**Date:** 2026-11-06
**Status:** Approved (v1 scope)
**Supersedes:** the social-calendar product direction archived at tag `archive-social-v1`

## Problem

Tasks and events get missed at four distinct points:

- **A — Capture.** The thought happened but was never recorded.
- **B — Resurface.** It was recorded, then buried in a list that never resurfaced it.
- **C — Placement.** It was seen, but no time was ever set aside, so it did not happen.
- **D — Delivery.** A reminder fired at a useless moment and was dismissed.

These are a chain, not four independent features: capture → resurface → place → deliver. Each link is worthless without the one before it. A list app that nails capture and ignores placement fixes nothing.

The core unsolved problem is **slip recovery**. Miss one day and the plan is wrong; every list app then becomes a guilt graveyard and gets abandoned. A planner that re-plans on slip is the whole product.

## Non-goals

Explicitly out of scope for v1, to be revisited per the phasing table:

- Voice capture, natural-language parsing, LLM duration inference
- Multiple capture surfaces (share sheet, home-screen widget, email ingest)
- Context-aware notification firing on location or device state
- Recurring tasks, task dependencies, project/tag hierarchies
- All social features. Those are archived and not coming back into this product.

## v1 scope — the spine

A thin vertical slice through all four failure modes:

1. One capture path only (in-app quick add)
2. Task model: title, duration estimate, deadline, priority
3. Free-gap extraction from Google Calendar
4. Greedy placement of tasks into real free gaps
5. Notification at slot start
6. Slip detection and re-plan, server-side

Slip recovery stays in v1 despite being the hard part. Without it, this ships as the same app shape that has already failed the user.

## Inherited from v1 social build

Kept, because it is working plumbing and the expensive part to rebuild:

| Path | Role |
|---|---|
| `lib/main.dart`, `lib/firebase_options.dart` | Firebase init, ProviderScope |
| `lib/config/providers/firebase_providers.dart` | Riverpod service wiring |
| `lib/config/router/` | go_router shell, bottom nav |
| `lib/core/theme/`, `lib/core/constants/` | Theme and constants |
| `lib/features/auth/` | Google Sign-In screen |
| `lib/services/auth/auth_service.dart`, `auth_token_service.dart` | Auth + OAuth token refresh |
| `lib/services/calendar/google_calendar_service.dart` | Calendar API client, incl. `listEvents(start, end)` |
| `lib/services/firestore/user_repository.dart` | User docs |
| `lib/models/user_model.dart` | User model |

Scrapped, because it is the social product surface:

`features/{feed,friends,events}`, `models/{friend_group,friendship,invitation,join_request,event}_model.dart`, `services/firestore/{friend_repository,friend_group_repository,friend_group_policy,invitation_repository,join_request_repository}.dart`, `services/visibility/`, `providers/{friends,notifications}_provider.dart`, `services/calendar/calendar_sync_service.dart`, and their tests.

### Known refactor debt

`GoogleCalendarService` is coupled to `EventModel`, which is being deleted. Its signatures must be reworked to take plain values or a `ScheduledSlot`. `listEvents(DateTime, DateTime)` already exists and is the basis for gap extraction; a `freeBusy` path is a later optimisation, not a v1 requirement.

## Architecture

```
┌─────────────── Flutter client ───────────────┐
│  features/capture   quick add → Task         │
│  features/plan      today / horizon view     │
│  features/triage    slipped + unplaceable    │
│                                              │
│  services/scheduler/                         │
│    free_gap_extractor   calendar → gaps      │
│    placement_solver     pure, deterministic  │
│    plan_writer          placements → slots   │
│                                              │
│  services/notifications/                     │
│    local_scheduler      next N slots         │
└──────────────┬───────────────────────────────┘
               │ Firestore (offline persistence on)
┌──────────────┴───────────────────────────────┐
│  Cloud Functions                             │
│    onSlotWindowElapsed   scheduled, 30 min   │
│      → mark missed → re-plan → FCM push      │
│    onTaskWrite           re-plan trigger     │
└──────────────────────────────────────────────┘
```

The solver is a pure function with no Firestore, no clock, and no I/O. Time and busy intervals are passed in. This is what makes it testable and what makes "why is this task here?" answerable.

## Data model

Firestore, all user-scoped under `users/{uid}`.

**`tasks/{taskId}`**

| Field | Type | Notes |
|---|---|---|
| `title` | string | |
| `notes` | string? | |
| `durationMinutes` | int | user estimate; v1 has no inference |
| `deadline` | timestamp? | null = no hard deadline |
| `priority` | enum | `high` / `normal` / `low` |
| `status` | enum | `inbox` / `scheduled` / `done` / `slipped` / `unplaceable` / `overdue`; `slipped` means stuck (see Slip recovery) and is distinct from a single missed slot |
| `splittable` | bool | may be chunked across gaps |
| `minChunkMinutes` | int | floor for a chunk; ignored unless splittable |
| `slipCount` | int | increments each missed slot |
| `createdAt` / `completedAt` | timestamp | |

**`slots/{slotId}`**

| Field | Type | Notes |
|---|---|---|
| `taskId` | string | |
| `start` / `end` | timestamp | UTC |
| `state` | enum | `planned` / `notified` / `started` / `done` / `missed` |
| `googleCalendarEventId` | string? | set if mirrored to Calendar |
| `planVersion` | int | stale slots from older plans are discarded |

**`planState/current`**

`planVersion`, `generatedAt`, `horizonStart`, `horizonEnd`, `lastReplanReason`.

**`busyCache/{dayKey}`** — cached busy intervals per local day, so planning works offline and does not hammer the Calendar API.

`planVersion` is the concurrency guard: a re-plan increments it, and any slot carrying an older version is ignored rather than raced against.

## Placement solver

Pure function. Input: tasks, busy intervals, working-hours preference, `now`. Output: placements plus an explicit unplaceable list.

1. Build free intervals = working window minus busy intervals, from `now` to `now + 14 days`.
2. Sort tasks by deadline ascending, then priority descending, then duration descending — earliest-deadline-first with a priority tiebreak.
3. First-fit each task into the earliest free interval that holds its duration. If `splittable`, chunk it across gaps, never below `minChunkMinutes`.
4. A task that cannot be placed before its deadline is returned as **unplaceable with a reason**, never silently dropped.

Greedy rather than a constraint solver, deliberately: it is deterministic, fast enough to run client-side, explainable to the user, and straightforward to test. EDF is optimal for feasibility on a single resource, which is the shape of this problem. If scheduling quality later demands it, the upgrade path is CP-SAT behind the same function signature.

**Silent drops are the trust-killer.** Every task is in exactly one visible state after a plan run.

## Slip recovery

- A slot whose window passes without `done` becomes `missed`; its task returns to `inbox` for re-placement and `slipCount` increments. A single miss is not a status change on the task beyond the counter.
- Re-plan runs and places it again.
- At `slipCount >= 3` the task's status becomes `slipped` — the **stuck** state — and demands explicit triage: shrink it, drop it, or hand-schedule it. It is not auto-requeued forever.
- A task past its deadline and undone becomes `overdue` and goes to triage rather than being hidden.

The stuck threshold is the anti-graveyard mechanism: the app admits the plan is not working instead of quietly rescheduling into infinity.

## Re-plan triggers

| Trigger | Where | Why |
|---|---|---|
| Task created or edited | client, on write | immediate feedback |
| App foregrounded | client | calendar may have changed externally |
| Slot window elapsed | Cloud Function, every 30 min | client cannot be trusted to be awake |
| Slot marked done early | client | frees a gap |

Google Calendar watch channels for external-change push are phase 2; v1 polls on foreground.

## Notification delivery

The binding constraint is platform, not product:

- **iOS caps pending local notifications at 64** and heavily restricts background execution. The client therefore cannot be the source of truth for re-planning. Only the next 20 slot notifications are scheduled locally; everything beyond that horizon, and every re-plan alert, arrives by FCM from the Cloud Function.
- **Android** needs `SCHEDULE_EXACT_ALARM` for exact slot alarms, and Doze will defer anything non-urgent — time-critical pushes go high-priority FCM.

`flutter_local_notifications` for scheduled local delivery, FCM for server-pushed. This constraint is what pushes the scheduler server-side, which is also the better engineering story: a distributed planner, not a client-side toy.

## Error handling

| Failure | Behaviour |
|---|---|
| Calendar API 401 | refresh via `AuthTokenService`; on hard failure, degrade to local-only planning with a visible banner |
| Offline | plan from `busyCache`, queue writes via Firestore offline persistence, reconcile on reconnect |
| Timezone / DST | store UTC, plan in the user's local zone, DST-aware via the `timezone` package |
| Solver finds no placement | explicit `unplaceable` state with reason, surfaced in triage |
| Concurrent re-plan | `planVersion` guard; stale-version slots discarded |

Degraded planning is always visible to the user. Silent degradation is treated as a bug.

## Testing

- **Solver** — pure Dart unit tests over golden scenarios: empty calendar, saturated calendar, deadline collisions, splittable chunking, DST boundary crossing, zero free gaps.
- **Repositories** — `fake_cloud_firestore`.
- **Cloud Functions** — Firebase emulator tests for slip detection and re-plan.
- **Widgets** — capture and plan screens.
- **Integration** — Firebase emulator suite covering capture → place → notify.

The solver's purity is what makes the valuable tests cheap. Any logic that needs a live Firestore to test belongs outside the solver.

## Phasing

| Phase | Scope | Failure mode addressed |
|---|---|---|
| 0 | the spine above | thin slice of A/B/C/D |
| 1 | voice + NL capture, duration inference | A properly |
| 2 | resurface logic, decay/defer, Calendar watch channels | B properly |
| 3 | context-aware delivery | D properly |

## Release

Android and iOS. Agent-doable: signing config, release build setup, ProGuard, iOS release scheme and permission strings, icons, privacy policy draft, Play data-safety draft, listing copy.

Requires the account holder: Apple Developer and Play Console access, cert and provisioning-profile generation, Firebase and GCP console setup (OAuth consent, Calendar API, SHA-1), store submission. If the Play account was created after Nov 2023 and has never published, production release is gated behind a closed test with 20+ testers for 14 continuous days — calendar time, not build time, is the critical path.
