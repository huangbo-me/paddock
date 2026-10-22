# PadDock beta progress

User approved productization; work completed in independent PadDock folder on codex/paddock-beta. The original working prototype and its two launch agents were not modified or stopped.

- Task 1 complete: policy, pairing/settings, 16 passing Swift regression tests.
- Task 2 complete: native bridge and 6 passing C safety assertions; final binary read-only self-check passed on the attached iPad.
- Task 3 complete: Chinese menu-bar/setup app, login control, diagnostics, guarded legacy migration and rollback. Migration was not executed against the user's only display.
- Task 4 complete for local internal beta: app/zip/DMG build scripts, local ad-hoc signature validation, packaging, documentation, one independent review and fixes. Final UI visual QA is pending because screenshot automation timed out; early UI accessibility state was checked.

Current environment has zero Developer ID signing identities. Public signing/notarization and hardware acceptance are pending, not claimed complete. Release script is supplied but not run.

Important fixes: native requests serialized, late connection reconciles requested disconnect, pairing requires stable single USB and successful callback, wireless transport never reported as USB, active legacy jobs found independently of plists, migration validates stable USB/mirror before and after stopping old jobs, unknown native interface blocks anchor release.

Documents file-provider metadata caused strict signature verification to fail after builds. Packaging uses an isolated temporary copy and strips only FinderInfo/ResourceFork metadata, never quarantine or security policy. Packaged binaries receive strict verification.

See TESTING.md for actual evidence versus remaining real-device scenarios.
