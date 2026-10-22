# PadDock Beta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a locally installable menu-bar app for paired USB Sidecar and headless support.

**Architecture:** SwiftUI setup presented by an AppKit menu-bar app, a pure Swift policy module, and a native Objective-C bridge for USB, Sidecar and virtual displays. One process owns connection and virtual-screen lifetimes; SMAppService controls login startup.

**Tech Stack:** Swift 5 language mode, SwiftUI/AppKit, Foundation, IOKit, CoreGraphics, ServiceManagement; no downloaded dependencies.

**Spec:** ../specs/2026-10-22-paddock-beta.md

## Global Constraints

- Apple Silicon macOS 14+; actually tested on this M4 mini only.
- No hardcoded user paths or device IDs in shipped app.
- Preserve legacy running setup until explicit migration.
- No public release without Developer ID signing and notarization.
- UI requests no accessibility/screen recording/root permissions.

## Review Focus

- Wrong or multiple USB iPads must not be silently bound.
- Pause/disconnect must not be undone by an automatic retry.
- A successful connection callback followed by disappearing display is failure.
- Removing the last virtual anchor must not silently strand the user.
- Legacy agents must not compete with the new app or be disabled before replacement is ready.

### Task 1: Policy and settings

Files: Sources/Core/Policy.swift, Tests/PadDockCoreTests/PolicyTests.swift, Package.swift.
Interface: Pairing, Observation, ConnectionPolicy.next(observation:now:), retry and verification deadlines; PairingCandidate validation.
- [x] Write tests for USB mismatch, pause, lock, ambiguity, online-display verification and exponential backoff; observe failure.
- [x] Implement value types and policy; run swift test green.

### Task 2: Native bridge

Files: Sources/Bridge/PadDockBridge.h/.m.
Interface: PDNative.snapshot(), connect/disconnect by identifier, create/release anchor, mirror anchor, USB change callback.
- [x] Reuse validated native mechanisms with runtime selector guards and asynchronous completion.
- [x] Compile Objective-C with -Wall -Wextra -Werror; inspect only real-device state by default.

### Task 3: Controller and app UI

Files: Sources/App/Controller.swift, Views.swift, Main.swift; Resources/Info.plist.
Interface: ObservableObject controller feeds setup dashboard and menu; persisted pairing/settings in application support.
- [x] Implement state loop, pairing only after USB success, explicit pause/disconnect, headless anchor lifecycle and SMAppService.
- [x] Detect legacy controller; provide explicit guarded migration and restore on failure.
- [x] Create setup/status/diagnostics UI and safe cleanup/quit actions.
- [x] Compile app and run policy regression tests.

### Task 4: Packaging and QA

Files: scripts/build.sh, scripts/release.sh, README.md, docs/TESTING.md.
- [x] Build app, create icon via code-native AppKit drawing, ad-hoc sign and assemble DMG + zip.
- [x] Verify bundle, signatures, generic configuration and read-only app launch; UI accessibility tree checked, final visual QA remains pending (screenshot timed out).
- [x] Request one fresh bounded code review while doing artifact checks; fix important findings with tests.
- [x] Document verified behavior, unverified hardware cases, and Developer ID/public-release prerequisites.
