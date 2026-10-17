# ClawBar

A native macOS port of Enhed's Windows widget clawd-usage-winwidget 1.3.0: a menu bar item with the Claude
session %, and a floating widget where the pixel mascot Clawd lives over a time-of-day sky. Behaviour follows the
original unless README.md's "Differences from the original" says otherwise.

## Toolchain

- Command Line Tools only: no Xcode, `xcodebuild`, `actool` or string catalogs.
- SwiftUI's macro plugin is missing, so `@State`, `@Entry`, `@Animatable` and `#Preview` do not compile. State lives
  in `@Observable` classes (that macro works) passed into views; environment values use a hand-written
  `EnvironmentKey` (see `uiScale` in `Sources/ClawBar/Views/Metrics.swift`).
- `Package.swift` adds the Swift Testing macro plugin path that Command Line Tools leave out; tests use
  `import Testing`. XCTest is absent.

## Layout and rules

- Every value the modules pass each other is a type in `Sources/ClawBarShared/`; each other target owns one concern
  (data, presenter, clawd, sky, app) and exports only its entry points.
- The `ClawBar` executable defaults to `MainActor` isolation; Timer and notification blocks run inside
  `MainActor.assumeIsolated`.
- `ClawdEngine`, `SkyEngine`, `SkyInfo` and `WidgetPresenter` are pure: time, time zone and randomness arrive as
  inputs (`SeededRandomSource` in tests). Statics are `let`; regular expressions are `NSRegularExpression`.
- Shipped targets carry no SwiftPM resources: `Bundle.module` breaks in the hand-assembled .app.
- The original rounds half to even (`[int]`, `[byte]`, `[math]::Round`): use `.rounded(.toNearestOrEven)`.
- Comments say why, in one line where one suffices.

## Safety

Tests use fake executables, temporary `AppPaths` roots (`CLAWBAR_HOME`) and fixtures. Never run `claude update`,
never open `~/.claude/sessions/*.key` (secrets), and keep `SMAppService` out of tests.

## Checking a change

- `swift build && swift test`.
- `.build/debug/ClawBar --snapshot <dir>` renders every widget state in English and German at k 1.0, 1.2 and 2.0,
  plus the menu bar item and both menus as text; open the PNGs to look.
- `ClawBar --diagnose` runs every probe once against the live system.
- With the app running: `ClawBar --dump-state` and `ClawBar --command <toggle|show|larger|smaller|refresh|quit|lang de>`
  (same `CLAWBAR_HOME` as the instance).
- `scripts/build-app.sh --install` rebuilds `~/Applications/ClawBar.app`, quitting a running copy first.

## Reference material

`docs.local/` (git-ignored, may be absent): `original/` is the PowerShell source, read as data and never executed;
`port-spec/` describes each original module. When behaviour is in doubt, the original's source wins.
