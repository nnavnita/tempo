# Play Console — Data Safety answers

Draft answers for the Data Safety form. These must match what the app
actually does; Play rejects listings where they do not, and the privacy
policy has to agree with them.

## Does your app collect or share any of the required user data types?

**Yes** — collects, does not share.

## Is all collected data encrypted in transit?

**Yes.** Firebase SDKs use TLS throughout.

## Do you provide a way for users to request data deletion?

**Yes** — in-app deletion of tasks, plus deletion on request by email.

---

## Data types

| Category | Type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|---|
| Personal info | Name | Yes | No | Required | App functionality, account management |
| Personal info | Email address | Yes | No | Required | App functionality, account management |
| Photos | Profile photo | Yes | No | Required | App functionality (shown in profile) |
| Calendar | Calendar events | Yes | No | Required | App functionality (finding free time) |
| App activity | Other user-generated content (tasks) | Yes | No | Required | App functionality |
| Device or other IDs | Device or other IDs | Yes | No | Required | App functionality (sending reminders) |

## Notes for the reviewer

- Calendar access is read plus insert on the user's primary calendar. Reading
  identifies busy time; inserting mirrors planned blocks onto the calendar as
  private events, and only when the user enables it.
- Only start and end times are cached from calendar events. Titles,
  descriptions, locations and attendees are not stored.
- The device identifier is the Firebase Cloud Messaging token, used solely to
  deliver the user's own reminders to their own device.
- No advertising or analytics SDKs are present.

## Sensitive permissions requiring declaration

| Permission | Why |
|---|---|
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | Reminders announce a block of work at its start time. Android's Doze defers inexact alarms, which would deliver the reminder after the block it refers to had already passed. |
| `POST_NOTIFICATIONS` | Delivering those reminders on Android 13+. |
| `RECEIVE_BOOT_COMPLETED` | Re-registering pending reminders after a restart, which otherwise clears them. |
