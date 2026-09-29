# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:46cd31e7 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

Requires Xcode 26.6 with the iOS 26.5 simulator runtime. Tests run on the pinned destination
**iPhone 17 Pro, iOS 26.5**: the snapshot references are only valid for that runtime.

```bash
scripts/ci-local.sh                  # every CI job except tvOS and visionOS, stops at the first failure
scripts/ci-local.sh lint ios         # a subset: lint, spm-macos, ios, catalyst, evolution, spm-linux (needs Docker)

# The same checks by hand
xcrun swift-format lint --strict --recursive Sources Tests Example/KinietaDemo
xcodebuild -scheme Kinieta -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
xcodebuild -scheme Kinieta -destination 'platform=macOS,variant=Mac Catalyst' test
xcodebuild -project Example/KinietaDemo.xcodeproj -scheme KinietaDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build
swift build && swift test            # macOS: the AppKit tests only; Linux: an empty module, 0 tests
xcodebuild -scheme Kinieta -destination 'generic/platform=iOS Simulator' build \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_SWIFT_FLAGS=-alias-module-names-in-module-interface

# Re-record snapshots after an intentional visual change, then review the PNGs
TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild -scheme Kinieta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test

# Build the DocC catalog; it should produce no warnings
xcodebuild docbuild -scheme Kinieta -destination 'generic/platform=iOS Simulator'
```

The tvOS build (`-destination 'generic/platform=tvOS Simulator' build`), the visionOS tests
(Apple Vision Pro / visionOS 26.5 simulator) and the optional `pod lib lint` job run in CI only
(`pod lib lint Kinieta.podspec --allow-warnings --platforms=ios` lints iOS locally). CI is
`.github/workflows/ci.yml`; keep it, `scripts/ci-local.sh` and README "Development" in sync.

## Architecture Overview

A UIKit animation library (iOS, tvOS, Mac Catalyst 17+, visionOS 1+), Swift 6, main-actor isolated,
with experimental AppKit support (macOS 14+, every property; layer properties give a view without a
layer one). Sources are behind `canImport(UIKit) || os(macOS)` (`os(macOS)` is false under
Catalyst); `Platform.swift` aliases `PlatformView` to `UIView` or `NSView` and `PlatformColor` to
`UIColor` or `NSColor`. Public signatures cannot use these internal aliases, so public API that
names the view or colour type is declared once per platform. Linux builds an empty module.

- `View.swift`: `UIView.animate(...)` / `wait(_:)` entry points; geometry goes through
  `center` and `bounds`, not `frame`; on `NSView`, through the unrotated frame about its centre.
- `Kinieta.swift`: the public handle. Each handle owns a `SequenceAction` (its timeline) and
  exposes the chain API (`easing`, `delay`, `then()`, `parallel()`, `repeat`, `onComplete`),
  control (`cancel`, `pause`, `resume`, `finished()`) and `Kinieta.group`.
- Actions: the `Action` protocol, with `SequenceAction` (one after another), `GroupAction`
  (together), `PropertyAnimation` (interpolates `Property` values on one view; its `owners`
  table gives each view and `Property.Key` to the newest animation started on it) and
  `PauseAction` (`wait`; `delay` is a pause sequenced before the action). A sequence's
  `ActionQueue` holds `ActionType` descriptions that become live actions only when they start,
  which is why chain calls can still edit actions that have not started.
- `Engine.swift`: `Engine.shared` advances registered actions by real elapsed time from a
  `FrameDriver` (a `CADisplayLink` in production, `ManualFrameDriver` in tests) and holds the
  global settings (colour interpolation, Reduce Motion, frame rate range).
- Easing: `Bezier` (baked lookup table, CSS `cubic-bezier()` semantics) and `Easing` presets.
- Colour: `ColorMath.swift` (RGB/HSB/LCH interpolation, sRGB and Display P3).
- `IgnoredCall.swift`: debug-only warnings for chain calls that do nothing.
- Docs: `Sources/Kinieta/Kinieta.docc`. Demo: `Example/KinietaDemo.xcodeproj`.
- Tests (Swift Testing) in `Tests/KinietaTests`, snapshots in `__Snapshots__`.

## Conventions & Patterns

- Formatting follows `.swift-format` (4 spaces, 120 columns); lint must pass with `--strict`.
- User-visible changes update `CHANGELOG.md` (Keep a Changelog, under `[Unreleased]`) and the
  README; public API changes also update the DocC catalog.
- Commits are per Beads ticket, with the ticket ID as the message prefix
  (`kinieta-xyz: summary`).
- Tests drive the engine frame by frame with `ManualFrameDriver` rather than waiting on real time.
  Every suite that touches `Engine.shared` takes `@Suite(.serialized, .usesSharedEngine)`, which
  runs its tests alone among all such suites.
