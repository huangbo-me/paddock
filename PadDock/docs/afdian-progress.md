# Afdian implementation ledger

Spec and plan: docs/superpowers/{specs,plans}/2026-10-22-afdian.md
User approved feature, 14-day trial and offline licenses; shop uncreated.
Ruling: proceed inline on codex/paddock-afdian under existing execution authorization; do not request repeated plan permissions. Separate installed app remains untouched.
Ruling: offline license does not enforce a one-Mac limit or remote refund revocation. Headless recovery is explicitly allowed after expiry for screen safety.
Tasks 1–3 implemented and verified, 2026-10-22.

Validation:
- 36 Swift tests passed (18 commerce, 2 isolated Keychain, 16 existing core).
- Six existing native display safety assertions passed.
- App and issuer compiled with warnings treated as errors.
- CLI generation, 100-code uniqueness/verification, tamper rejection, file permissions, overwrite protection and URL checks passed.
- 100 live inventory codes verified; separate owner code verified by the built app against its bundled public key, without activation.
- Independent in-memory preview: trial begins with 14 days, unavailable purchase disabled, invalid code yields error without disturbing trial. No installed-app changes.
- DMG checksum and strict ad-hoc signature checks passed for both DMG and zip app copies. Public configuration matched; bundle whitelist and raw/base64 private-material scan passed.
- Installed /Applications/PadDock.app remains version 0.1.0.

One independent final review identified display-classification and noninteractive-Keychain recovery issues. Both fixed and covered by tests. Online built-in screens are the only positive independent-screen evidence; all external/virtual/dummy displays conservatively retain paired headless recovery. Explicit user actions permit scoped Keychain authorization, automatically reverting to noninteractive background access even after errors.

Not verified: real payment/automatic delivery/inventory consumption (shop uncreated), cross-signature Keychain prompt on upgrade, full 0.2.0 headless hardware regression. Not shipped as a public signed/notarized release. Next external dependency: create Afdian digital product and supply its URL, then configure/rebuild and conduct a real order test. See AFDIAN_SETUP.md.
