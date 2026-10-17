# Changelog

Notable changes to dmenu-mac, for people who use it. Every GitHub release also lists the pull requests behind it.

## 0.9.0

Search shortcuts, aliases, usage-based ranking, and a short setup on first launch.

### Added

- First-run setup that walks through the hotkey (and the Spotlight conflict), launch at login and terminal programs, and can ask for Automation access to Terminal or iTerm2 up front. Enter continues, Esc skips, and **Run Setup Again…** in the menu bar reopens it. Existing installs and launches from a shell skip it.
- Search shortcuts: type a keyword, a space and a query, such as `g swift actors`, to search Google, DuckDuckGo, GitHub, YouTube or Wikipedia, ask Claude, ChatGPT or Perplexity, or start Claude Code (`cc`) or Codex (`cx`) in your terminal. Edit them in Settings → Shortcuts.
- Aliases: give any item a short keyword in Settings → Aliases, like `ff` for Firefox. Typing it puts that item first.
- Results are ranked by how often and recently you opened them, and the ones you use most come first before you type anything.
- ⌘ Enter reveals the selected item in Finder, ⌥ Enter copies its path, and ⌃ Enter opens a new instance of the app.
- Pick the screen the bar appears on in Settings → Appearance: the one with the active window, the one with the mouse pointer, or the primary screen. `-m`/`--monitor <n>` picks a screen for a single run.
- **Show icons** in Settings → Appearance shows app and System Settings icons next to results. Off by default.
- Available in nixpkgs: `nix profile install nixpkgs#dmenu-mac`, or `pkgs.dmenu-mac` in nix-darwin and home-manager.

### Changed

- Launch at Login moved from the menu bar icon to Settings → General.
- While Setup or Settings is open, dmenu-mac shows in the Dock and the app switcher, so a window that went behind others can be found again. Closing it hands focus back to the app you were in.
- The bar spans the full width of its screen and stays clear of the menu bar and the Dock on every display, including with the Dock on the side.

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
