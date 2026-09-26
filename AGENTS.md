# AGENTS.md

@README.md

The README covers the project, usage, and build/test/lint commands. Update the README whenever something applies to humans too. Keep this file for agent-only notes.

## Gotchas

- Argument parsing is skipped under XCTest (`XCTestConfigurationFilePath`). Otherwise `parseOrExit()` kills the test runner.
- In tests, inject `MockListProvider` instead of touching the filesystem or stdin.
- `src/3rd-party/DDHotKey*` and `src/SettingsViewController.swift.backup` are legacy and unused. Hotkeys go through KeyboardShortcuts.

## Git Commits

Plain commit messages, with no Claude Code references or co-authorship attribution.
