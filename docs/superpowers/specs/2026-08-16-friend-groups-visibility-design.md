# Friend Groups & Fine-Grained Event Visibility — Design

## Context

Tempo's current visibility model is a flat three-tier enum on `EventModel.visibility`: `private` / `friends` / `everyone`. Friends are a single flat list (`friendships` collection, one doc per accepted pair). There is no way to:

- Organize friends into named sub-groups (housemates, hiking crew, coworkers).
- Share an event with a specific group or a specific individual outside the blunt three-tier model.
- Explicitly hide an event from a specific person or group even when the base tier would otherwise show it to them.

This is the first of five sub-projects decomposed from a broader "social calendar / planner" feature request (the others — open/public discovery, event content hub, payments/marketplace — are separate specs, sequenced after this one since they depend on groups + visibility existing).

## Goals

- Users can create private, named groups of friends (e.g. "Housemates"), with a friend able to belong to multiple groups.
- Groups are private to their owner — members are not told they're in a group or who else is in it.
- An event's visibility can combine the existing base tier (private/friends/everyone) with an additional "also share with" set of specific groups and/or individual friends, and a separate "hide from" set of specific groups and/or individuals that overrides the above.
- Firestore security rules enforce all of this without needing per-request loops or dynamic `get()` calls over arbitrary-length group lists.

## Non-goals

- Open/public discovery of events by non-friends (separate spec).
- Event media, posts, todo/shopping lists (separate spec).
- Payments/marketplace features (separate spec).
- Retroactive visibility updates when group membership changes after an event was saved (see Decision: snapshot timing below).

## Data model

### New collection: `friend_groups`

```
friend_groups/{groupId}
  ownerUid: string
  name: string
  memberUids: string[]
  createdAt: Timestamp
  updatedAt: Timestamp
```

- One document per group, owned by a single user.
- `memberUids` references `users/{uid}` — no requirement that members are mutual friends, but UI only offers accepted friends when adding members.
- Private to owner: no read rule allows a member to query groups they belong to; only the owner can read/write their own `friend_groups`.

### `EventModel` additions

Editable source fields (set via UI, persisted as-is):

```
includeGroupIds: string[]     // "also share with" — groups
includeFriendUids: string[]   // "also share with" — individuals
excludeGroupIds: string[]     // "hide from" — groups
excludeFriendUids: string[]   // "hide from" — individuals
```

Denormalized fields (computed client-side at create/update time, used by security rules):

```
visibleUids: string[]   // flattened union of includeGroupIds' members + includeFriendUids
excludeUids: string[]   // flattened union of excludeGroupIds' members + excludeFriendUids
```

### Decision: snapshot at save time, not live

Firestore security rules cannot loop over a dynamic list of group IDs and `get()` each one to check membership — there's no forEach-with-get construct usable against an arbitrary-length array in rules. The practical fix is to flatten group membership into a plain array (`visibleUids`/`excludeUids`) on the event document itself at write time, so the rule is a simple `in` check.

The trade-off: if someone is added to a group *after* an event was shared with that group, they will not retroactively see that past event unless the owner re-saves the event (which recomputes the snapshot). This was chosen deliberately over the alternative (a Cloud Function trigger on group-membership changes that fans out and rewrites all affected events) to avoid introducing Cloud Functions as a new infra dependency for a first version. Revisit if this proves confusing in practice.

## Security rules

Replace the `events` match block's `allow read` with:

```
allow read: if isSignedIn() && (
  isOwner(resource.data.ownerUid)
  || request.auth.uid in resource.data.attendeeUids
  || (
    !(request.auth.uid in resource.data.excludeUids) && (
      resource.data.visibility == 'everyone'
      || (resource.data.visibility == 'friends' && areFriends(request.auth.uid, resource.data.ownerUid))
      || request.auth.uid in resource.data.visibleUids
    )
  )
);
```

Key property: **owner and attendee access always bypasses `excludeUids`.** An explicit invite or an approved join-request is a stronger, more specific grant than a group-based exclude list — if the owner invited someone directly, a stale or unrelated exclude entry must not silently revoke that. `excludeUids` only gates the tier-based paths (`everyone` / `friends` / `visibleUids`).

`excludeUids` applies across all tiers, including `everyone` — this is what makes "public event, but hidden from my ex" or "public event, hidden from my coworkers group" possible.

Other collections (`friend_groups`) get straightforward owner-only rules:

```
match /friend_groups/{groupId} {
  allow read, write: if isSignedIn() && isOwner(resource.data.ownerUid);
  allow create: if isSignedIn() && isOwner(request.resource.data.ownerUid);
}
```

## UI / UX flows

### Group management

New screen under `features/friends/` (e.g. `manage_groups_screen.dart`):
- List existing groups.
- Create / rename / delete a group.
- Add/remove members via the existing friend picker (reuse whatever component `user_search_screen.dart` / friend list already provide for selecting friends).

### Event visibility picker

Overhaul `features/events/widgets/visibility_selector.dart`:
- Base tier stays as-is: Private / Friends / Everyone chips.
- New "Also share with" section: multi-select of the owner's groups + individual friends → feeds `includeGroupIds` / `includeFriendUids`. Available regardless of base tier (so e.g. `private` + include one group is a valid "share with just this group" pattern).
- New "Hide from" section: same multi-select shape → feeds `excludeGroupIds` / `excludeFriendUids`. Available regardless of base tier.

### Save flow

`EventService.createEvent` / `updateEvent` gain a resolution step before writing:
1. Read the owner's `friend_groups` (already have read access, owner-only).
2. Expand `includeGroupIds` → member uids, union with `includeFriendUids`, dedupe → write to `visibleUids`.
3. Same expansion for `excludeGroupIds` + `excludeFriendUids` → `excludeUids`.
4. If a referenced group no longer exists (deleted since last edit), drop it silently from the expansion rather than erroring.

### Query impact

Calendar/feed screens currently merge several queries client-side (owner / everyone / friends-tier / attendee) since Firestore can't OR across these conditions server-side. Add a fifth query: `visibleUids array-contains myUid`, merge + dedupe with the existing result set the same way. Requires a new composite index (`visibleUids` + `startTime`, following the existing index pattern documented in `SETUP.md`).

## Testing

- **Unit**: visibility resolution service — group expansion, dedup, empty groups, owner-is-self no-op, deleted-group-ref handling.
- **Firestore rules** (`@firebase/rules-unit-testing`): owner reads own private event; friend reads friends-tier event; excluded friend blocked on friends-tier; excluded *attendee* still allowed (bypass verified); custom-group member allowed via `visibleUids`; non-member blocked; everyone-tier minus excluded person blocked.
- **Widget**: visibility selector round-trips a selection (groups + individuals, include + exclude) into the correct model fields on save.

## Open questions

None outstanding — all resolved during design (see Decisions above).
