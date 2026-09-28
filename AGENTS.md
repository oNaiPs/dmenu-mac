# AGENTS.md

@README.md

The README covers the project, usage, and build/test/lint commands. Update the README whenever something applies to humans too. Keep this file for agent-only notes.

## Gotchas

- Argument parsing is skipped under XCTest (`XCTestConfigurationFilePath`). Otherwise `parseOrExit()` kills the test runner.
- In tests, inject `MockListProvider` instead of touching the filesystem or stdin.
- Most bundles in `/System/Library/PreferencePanes` are empty stubs that System Settings maps by name. `AppListProvider.deadPreferencePanes` lists the ones that no longer map; to re-check, `open` each stub and read `tell application "System Settings" to get id of current pane` via osascript.

## Releases

- The process and the signing secrets are in `RELEASING.md`.
- The version lives only in `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.pbxproj`; `Info.plist` reads them. Never hardcode a version in the plist.
- `scripts/release.sh` is the only thing that should create version tags; the Release workflow refuses tags that don't match the project version.
- Hardened runtime is on. Anything new that needs an entitlement (Apple Events, etc.) goes in `src/dmenu-mac.entitlements`, or notarized builds break at runtime while Debug builds keep working.

## Git Commits

Plain commit messages, with no Claude Code references or co-authorship attribution.
