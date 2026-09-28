# dmenu-mac

[![ci](https://github.com/oNaiPs/dmenu-mac/workflows/Build/badge.svg)](https://github.com/oNaiPs/dmenu-mac)

A keyboard-only application launcher for macOS, inspired by [dmenu](https://tools.suckless.org/dmenu/).

Press a hotkey, type a few letters, hit Enter. No Spotlight indexing, no mouse, no waiting.

![dmenu-mac demo](./demo.gif)

## Installation

Requires macOS 13.5 or later.

With [Homebrew](https://brew.sh/):

```sh
brew install dmenu-mac
```

Or download the latest `dmenu-mac.zip` from the [releases page](https://github.com/oNaiPs/dmenu-mac/releases), unzip it, and move `dmenu-mac.app` to `/Applications`. Releases are signed and notarized by Apple.

To call `dmenu-mac` from scripts, put `dmenu-mac.app/Contents/Resources/dmenu-mac` on your `PATH`. Homebrew does this for you.

## Quick start

1. Open dmenu-mac. It lives in the menu bar and waits for its hotkey.
2. Press **⌘ Space** anywhere to bring up the launcher.
3. Start typing. Matching is fuzzy and case-insensitive, so `safri` still finds Safari.
4. Press **Enter** to open the highlighted result, or **Esc** to dismiss.

Tip: dmenu-mac is best paired with Spotlight's shortcut turned off (System Settings → Keyboard → Keyboard Shortcuts → Spotlight), or pick a different hotkey in dmenu-mac's settings.

### Keys

| Key | Action |
| --- | --- |
| **⌘ Space** | Show the launcher (configurable) |
| **Tab** / **→** | Move to the next result |
| **Shift Tab** / **←** | Move to the previous result |
| **Enter** | Open the selected result, or run what you typed when nothing matches |
| **Shift Enter** | Run what you typed even if there are matches |
| **Esc** | Hide the launcher |
| **⌘ ,** | Open Settings |

The launcher does not steal focus: the app you were in stays in front and gets the keyboard back as soon as the bar closes.

## What it finds

- Apps in `/Applications`, `/System/Applications`, and `~/Applications`, including symlinked folders such as the ones nix-darwin and home-manager create.
- Bundled utilities like Keychain Access, Archive Utility, and Directory Utility.
- System Settings panes, so `disp` opens Displays and `net` opens Network.
- Optionally, command-line programs from your `$PATH` (see below).

The list refreshes on its own when apps are installed or removed.

## Running commands

If nothing matches what you typed, Enter runs the text as a shell command in your login shell, from your home directory. `mpv ~/Movies/clip.mp4` plays a video without opening a terminal. Shift Enter does the same even when something matches.

### Terminal programs

To launch `nvim`, `htop`, `ranger`, and friends in a terminal window:

1. Open Settings → General and turn on **List programs from $PATH**.
2. Pick your terminal: Terminal, iTerm2, Ghostty, Alacritty, kitty, WezTerm, or a custom command where `{cmd}` is replaced by the program to run.

Programs from your login shell's `$PATH` (Homebrew, nix, `~/.local/bin`, ...) then show up alongside apps, and typed commands like `nvim notes.md` open in that terminal too. The first time Terminal or iTerm2 is used, macOS asks to let dmenu-mac control it.

## Settings

Open Settings with **⌘ ,** while the launcher is up, or from the menu bar icon.

- **General**: the global hotkey, and the terminal setup described above.
- **Appearance**: bar position (top or bottom of the screen), opacity, colors for the text, selection, and background, and the font and its size. **Reset to Defaults** undoes it all.

The menu bar icon also lets you show the launcher, turn **Launch at Login** on or off, and quit.

## Command line

The `dmenu-mac` command takes a few flags, which makes it usable from scripts and hotkey daemons:

```sh
dmenu-mac --help
```

| Flag | Effect |
| --- | --- |
| `-p`, `--prompt <text>` | Show a prompt instead of the search field |
| `-b`, `--bottom` | Show the bar at the bottom of the screen for this run |
| `--no-custom` | Only accept items from the list; typed text that matches nothing is ignored |
| `--exit` / `--no-exit` | Quit after a selection, or stay in the background |

### Menus for scripts

Pipe a list of choices in and the selection is printed to stdout, just like dmenu:

```sh
choice=$(printf 'Yes\nNo' | dmenu-mac -p "Are you sure?")
```

When nothing matches (or with Shift Enter) the typed text is printed instead, unless you pass `--no-custom`. Pressing Esc prints nothing and exits with status 1.

### Binding to a key with another tool

When started from a shell or a hotkey daemon such as [skhd](https://github.com/koekeishiya/skhd), dmenu-mac exits as soon as you pick something or press Esc, so it can be bound to a key without leaving processes behind:

```
# ~/.config/skhd/skhdrc
alt - space : dmenu-mac
```

When opened as an app (Finder, Dock, Launch at Login) it stays running and waits for its hotkey. Use `--exit` or `--no-exit` to force either behaviour.

## Why not Spotlight?

Spotlight has to index everything on disk, and on machines with a lot of files that keeps the CPU busy and the results slow. dmenu-mac only looks at your application folders, so it starts instantly, needs no index, and keeps working with Spotlight disabled entirely.

## Development

```sh
xcodebuild -skipPackagePluginValidation -skipMacroValidation \
  -project dmenu-mac.xcodeproj -scheme dmenu-mac -configuration Debug test
# single test: add -only-testing:dmenu-macTests/SearchServiceTests[/testName]

swiftlint --strict   # CI fails on warnings
```

`-skipPackagePluginValidation` is required because SwiftLint runs as an Xcode build plugin.

Releases are cut with `scripts/release.sh`, see [RELEASING.md](RELEASING.md).

Bug reports and pull requests are welcome.

## License

GPL-3.0. See [LICENSE](./LICENSE).

## Authors

[@onaips](https://twitter.com/onaips)
