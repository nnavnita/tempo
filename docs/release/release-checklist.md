# Release checklist

Split by who can actually do each step. Everything in the first section is
done or scriptable; everything in the second needs the account holder's
credentials and cannot be delegated.

## Done in the repo

- [x] Android release signing wired to `android/key.properties` (gitignored),
      falling back to the debug key so local release builds still run
- [x] R8 minify and resource shrinking on release, with ProGuard rules
      keeping `com.dexterous.**` — stripping it makes pending reminders
      silently vanish after a reboot
- [x] Notification permissions: `POST_NOTIFICATIONS`,
      `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`
- [x] Boot receivers so pending reminders survive a restart or app update
- [x] iOS `UIBackgroundModes`: `remote-notification` and `fetch`, needed for
      the re-plan push to wake the app
- [x] Privacy policy draft — `privacy-policy.md`
- [x] Play Data Safety answers — `play-data-safety.md`
- [x] Listing copy and screenshot plan — `store-listing.md`
- [x] Firestore security rules, owner-only with an explicit deny-all
      fallthrough
- [x] Composite indexes for the elapsed-slot query

## Needs Navnita

These need identity, payment, or 2FA. No agent can hold them.

### Before a build can be uploaded

- [ ] Generate the upload keystore:
      `keytool -genkey -v -keystore ~/tempo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Copy `android/key.properties.example` to `android/key.properties` and
      fill it in. **Back up the `.jks` and its passwords** — losing the
      upload key means you cannot update an existing Play listing without
      Google's key-reset process.
- [ ] Xcode: select the team, let it generate the iOS signing certificate
      and provisioning profile
- [ ] Confirm the iOS bundle identifier matches the Firebase iOS app
      registration

### Firebase / GCP console

- [ ] Confirm the Google Calendar API is enabled on project `tempo-3ac43`
- [ ] OAuth consent screen: fill in app name, support email, the hosted
      privacy policy URL, and the `calendar` scope justification. **The
      calendar scope is sensitive — Google requires a verification review,
      and that review has its own turnaround.** Start it early.
- [ ] Register the release SHA-1 in Firebase (the upload key's, not just
      debug), then re-download `google-services.json`
- [ ] Deploy rules and indexes: `firebase deploy --only firestore`
- [ ] Deploy functions: `cd functions && npm install && firebase deploy --only functions`
- [ ] Confirm the Blaze plan is active — scheduled functions require it

### Store setup

- [ ] Host the privacy policy at a public URL
- [ ] Produce the icon and feature graphic listed in `store-listing.md`
- [ ] Capture the six screenshots per the plan
- [ ] Play Console: create the app, complete Data Safety, content rating,
      and the ads declaration (no ads)
- [ ] **Check whether the 20-tester / 14-day closed testing requirement
      applies.** It hits personal Play accounts created after November 2023
      that have not published before. If it applies, this is the critical
      path — start the closed test as early as possible, because the clock
      is calendar time, not build time.
- [ ] App Store Connect: create the app record, complete the privacy
      questionnaire, submit for review

## Known limitations shipping in v1

- The planning time zone is a fixed default (`Australia/Melbourne`) rather
  than read from the device. Resolving an IANA zone on-device needs a
  platform channel; getting it wrong silently shifts every working window,
  so v1 pins it and exposes it as a provider for a settings screen to
  override. **Anyone outside that zone will get wrong working hours.**
- Working hours are not user-editable yet — weekdays 9am–6pm.
- Slots are not mirrored onto Google Calendar by default. The service method
  exists (`insertSlotEvent`) but nothing calls it; planned blocks live only
  in the app for now.
- Dark mode is implemented in the theme but `ThemeMode.light` is pinned,
  because the planner screens still use light-only colour tokens.
