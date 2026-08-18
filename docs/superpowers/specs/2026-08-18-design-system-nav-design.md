# Design system + navigation/IA skeleton

**Status:** Approved (Spec 1 of a phased whole-app visual redesign)
**Scope:** Design tokens (color, typography, elevation, dark mode) and the top-level navigation/IA structure. Per-screen layout redesigns (calendar, feed, friends, events, profile) are out of scope here and get their own follow-up specs, built on top of this foundation.

## Motivation

Current UI is default Material3 `ColorScheme.fromSeed` — functional but generic, no distinct identity, and has no dark theme (`lib/core/theme/app_theme.dart` only exposes `lightTheme`). The app is nearing real-user readiness (T1 MVP converging in `bullseye.yaml`), so this pass gives Tempo a "warm & social" visual identity and dark mode support before more screens (T2 friend-group visibility) get built on top of it.

## Visual direction: "Warm & Social"

Selected via visual comparison (mockups in `.superpowers/brainstorm/`, not committed).

### Color — Terracotta & Sage

| Token | Light | Dark |
|---|---|---|
| Primary (terracotta) | `#C9603D` | `#D97A54` |
| Secondary/accent (sage) | `#6B8E5A` | `#7BA366` |
| Background | `#F6F2EC` (warm cream) | `#121212` (true dark) |
| Surface / card | `#FFFFFF` | `#1E1E1E` |
| Card border | `#F0F0F0`-ish warm hairline | `#2A2A2A` |
| Primary text (onSurface) | `#2B2823` | `#F0EDE8` |
| Secondary text (onSurfaceVariant) | `#8C8577` | `#9C968D` |

Primary (terracotta) is used for the active nav state, primary buttons/FAB, and brand accents. Sage is reserved for affirmative/secondary actions (e.g. a "Join" button distinct from the primary CTA) — the two accents should not compete for the same role on one screen.

Rationale for true dark over warm-brown dark: OLED battery efficiency and higher contrast outweigh the slightly cozier warm-dark alternative, given this is a mobile-first app.

### Typography

Single system sans (platform default: SF on iOS, Roboto on Android) across the whole app — no serif/sans split. Hierarchy comes from weight and size only, consistent with the existing `AppTheme` approach (e.g. `AppBarTheme.titleTextStyle` at w600/18px). This keeps the type system low-maintenance and matches Flutter/Material conventions rather than introducing a second font family to manage across platforms.

### Elevation & shape

Keep the existing flat, hairline-bordered approach already in `app_theme.dart` (cards: 0 elevation, 16px radius, 1px border; buttons: 0 elevation, 12px radius) — it reads as clean and modern and doesn't conflict with the warm palette. No change needed here beyond re-coloring for dark mode.

## Navigation / IA

Current: 5-tab bottom nav (Calendar, Feed, Friends, Alerts, Profile), defined in `lib/config/router/app_router.dart` (`ShellRoute` + `NavigationBar`), plus a separate FAB presumably on the calendar screen for event creation.

New structure:

- **4 bottom tabs**: Calendar, Feed, Friends, Profile.
- **Alerts** moves off the tab bar to a **bell icon with an unread-dot badge** in the top app bar, present on every tab screen (not just one). This matches how most social apps (not just calendar apps) surface notifications and frees a tab slot.
- **Create Event** gets a **raised center FAB embedded in the nav bar itself** (not a separately floating FAB elsewhere), making it the single most prominent tap target — appropriate since inviting people to something is the app's core social action.

Structurally: the nav bar becomes 4 flex slots + 1 raised center slot for the FAB. The FAB slot is a normal item in the nav row (not an absolutely-positioned overlay), sitting in its own box separate from any clipping/rounded-corner wrapper so its top isn't visually clipped — see the mockup iteration in this session for the layout bug that motivated this note (`.navdemo-screen` and `.navdemo-bar` must be sibling boxes with independent `border-radius`/`overflow`, not nested under one `overflow: hidden` wrapper).

### Routing implications

- `RouteConstants.notifications` route stays (bell icon still navigates there), it's just no longer a `NavigationBar` destination — becomes a top-app-bar action button instead.
- `RouteConstants.createEvent` — currently reached via FAB; FAB moves from wherever it currently lives (likely `CalendarScreen`) into the shared `ShellRoute` scaffold so it's available from Calendar and Feed at minimum. Confirm during implementation whether it should show on all 4 tabs or only Calendar/Feed (open question, not blocking this spec — default to showing on all 4 unless implementation reveals a reason not to).

## Out of scope (deferred to follow-up specs)

- Calendar screen layout
- Feed screen layout
- Friends screen layout (including future T2 group-visibility UI)
- Events create/edit screen layout
- Profile screen layout
- Auth/onboarding screens

Each of the above gets built on top of the tokens and nav/IA skeleton defined here, as its own spec.

## Implementation notes

- `lib/core/theme/app_colors.dart` — replace seed values (`primary`, `secondary`, `surface`, `background`, `onSurface`, `onSurfaceVariant`) with the terracotta/sage light-mode tokens above. Add a nested `AppColors.dark` class holding the dark-mode counterparts (`AppColors.dark.primary`, `AppColors.dark.background`, etc.), so call sites pick light/dark explicitly rather than relying on ambient theme lookups everywhere. The existing semantic tokens not covered by this spec's palette work (`busySlot`, `privateEvent`, `friendsEvent`, `publicEvent`, the three `visibility*Bg` chip colors) need dark equivalents added under the same `AppColors.dark` class — pick values that hold the same relative contrast/role against the new dark background, exact values left to implementation.
- `lib/core/theme/app_theme.dart` — add `AppTheme.darkTheme` alongside existing `lightTheme`, mirroring every themed component (`cardTheme`, `elevatedButtonTheme`, `inputDecorationTheme`, `navigationBarTheme`, `floatingActionButtonTheme`, `dividerTheme`) with dark tokens.
- `lib/main.dart` — wire `darkTheme:` and `themeMode: ThemeMode.system` (or a user preference toggle, if one already exists/is wanted — not currently in scope) into the `MaterialApp`.
- `lib/config/router/app_router.dart` — remove Alerts from `NavigationBar` destinations (drop to 4), add bell+badge action to the shared app bar, relocate the FAB into the shell scaffold as a nav-bar-embedded center element rather than a per-screen floating FAB.

## Testing

- Golden/widget tests (if the project has any — none observed under `test/` beyond default scaffolding) should be updated for the `NavigationBar` destination count change (5 → 4) and new FAB placement.
- Manually verify dark mode via `flutter run` with system dark mode toggled, across all 4 tabs, checking card/border/text contrast.
- Manually verify the bell badge dot appears/disappears correctly tied to unread notification state (existing notification provider, no new logic needed — this is purely a placement change).
