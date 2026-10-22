# PadDock local beta

Build the user-approved Mac menu-bar product from the working USB Sidecar / virtual-display prototype. Working product name: PadDock. Deliver a self-contained Apple Silicon macOS 14+ .app, drag-install DMG, source and build instructions. This is an internal beta, not a commercially signed release.

## Required user flow

- Chinese-first polished setup window and menu-bar control, with status and actionable errors.
- Enumerate connected iPads and Sidecar devices. Bind only after an explicit user selection and a successful forced-USB connection. Refuse ambiguous multiple USB iPad situations. Save identifiers locally, never ship the current user's IDs.
- Automatically connect only the paired USB device, only in the logged-in unlocked session. Pause must suppress retries. Explicit disconnect pauses automation. Verify online display after connection, not just callback success. Back off failures.
- Optional virtual display support prevents macOS terminating Sidecar when it is the last online display. Mirror the virtual display to iPad so no invisible extra desktop remains. Keep its lifetime in the app process; handle safe exit and disable flow.
- Use SMAppService for launch at login. User can unregister it and clear app configuration. No root, accessibility, or screen-recording privileges requested by our app.
- Detect legacy prototype agents by their known labels. Do not silently run a competing controller or remove live virtual screens. Offer a reviewable migration path: create new anchor first, then stop legacy services. Roll back if activation fails. User controls this action.
- No purchases, licensing server, cloud telemetry, or published website in this deliverable. Diagnostics omit device identifiers and user paths.
- Runtime API capability checks; macOS private API dependency clearly disclosed in setup/about. FileVault login limitation shown.
- Existing working iPad configuration must not be disrupted during development or read-only UI QA.

## Validation

Core tests cover pairing ambiguity, manual pause, USB removal, lock, stable connection verification, retry backoff and mismatch. Compile with warnings treated as errors. App bundle/signature/plist verification. Read-only launch/UI QA against the real machine, followed by explicit migration and real USB/headless checks only when appropriate. No reboot automatically.

No Developer ID certificate is available in the local keychain. Produce ad-hoc signed local beta artifacts and a documented Developer ID + notarization release workflow; do not advertise them as ready for public commercial download.
