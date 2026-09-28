# Changelog

Notable changes to dmenu-mac, for people who use it. Every GitHub release also lists the pull requests behind it.

## 0.8.0

The first release in five years, and the first one signed and notarized by Apple: it opens without Gatekeeper warnings and the Homebrew cask works again.

### Added

- Menu bar icon with Show, Settings, Launch at Login and Quit.
- Settings window (⌘ ,): General for the hotkey and terminal, Appearance for bar position, opacity, colors, font and size, with Reset to Defaults.
- The bar can sit at the top or bottom of the screen; `-b`/`--bottom` picks the bottom for a single run.
- System Settings panes show up as results: `disp` opens Displays, `net` opens Network.
- Apps in `~/Applications` and in symlinked folders (nix-darwin, home-manager) are found too.
- Enter runs what you typed as a shell command when nothing matches; Shift Enter does it even when something matches.
- Optional listing of command-line programs from your `$PATH`, opened in Terminal, iTerm2, Ghostty, Alacritty, kitty, WezTerm or a custom command.
- `--no-custom` for scripts that should only accept items from the list.
- `--exit` / `--no-exit` to choose whether dmenu-mac quits after a selection.
- Paste and the usual editing shortcuts in the search field.

### Changed

- Requires macOS 13.5 or later (was 10.13).
- The launcher no longer steals focus: the app you were in stays in front and gets the keyboard back as soon as the bar closes.
- Started from a shell or a hotkey daemon such as skhd, dmenu-mac exits after a selection or Esc instead of staying around.
- Esc on a piped menu prints nothing and exits with status 1, like dmenu.
- Piped input is read until EOF and decoded as UTF-8, so long lists and non-ASCII items work.
- The bar stays above the Dock and below the menu bar.
- Results draw faster.
- The `dmenu-mac` command-line wrapper no longer needs python3.
- The hotkey is handled by KeyboardShortcuts instead of the unmaintained DDHotKey.
- No longer sandboxed, which is what allows running shell commands and reading the real `~/Applications`.

### Fixed

- Crash when pressing Tab with no results, and an infinite recursion while editing the search field.
- Search text color is applied to the placeholder and while editing.
- The search field is cleared when the window hides.
- The Settings window always comes to the front.
- Version numbers in the app bundle.
