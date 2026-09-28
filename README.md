
# dmenu-mac

[![ci](https://github.com/oNaiPs/dmenu-mac/workflows/Build/badge.svg)](https://github.com/oNaiPs/dmenu-mac)



dmenu inspired application launcher.

![dmenu-mac demo](./demo.gif)

## Who is it for
Anyone that needs a quick and intuitive keyboard-only application launcher that does not rely on spotlight indexing.

## Why
If you are like me and have a shit-ton of files on your computer, and spotlight keeps your CPU running like crazy.

1. [Disable spotlight](https://www.google.com/search?q=disable+spotlight+completely) completely and its global shortcut (recommended but not necessary)
3. Download and run dmenu-mac

## How to use
1. Open the app, use cmd-Space to bring it to front.
2. Optionally, change the binding in Settings (cmd-, or the menu bar icon > Settings…).
3. Type the application you want to open, hit enter to run the one selected.

dmenu-mac lives in the menu bar. From its icon you can open the launcher, open Settings, turn Launch at Login on or off, and quit. Opening the app again from Finder brings up the launcher.

### Window position
The bar sits at the top of the screen by default. Pick Top or Bottom under Settings → Appearance → Window Position,
or pass `-b`/`--bottom` to put it at the bottom for a single run, like dmenu.

### Commands
If nothing matches, enter runs what you typed as a shell command in your login shell, from your home directory (e.g. `mpv test.mp4`). Shift-enter does the same even when there are matches.

### Running from a shell
When opened as an app (Finder, Dock, login items), dmenu-mac stays in the background waiting for its hotkey.
When started from a shell or a hotkey daemon like [skhd](https://github.com/koekeishiya/skhd), it exits after
you pick an app or press Esc, so it can be bound to a key without piling up processes.
Use `--exit` or `--no-exit` to force either behaviour.

### Pipes
You can make dmenu-mac part of your scripting toolbox, use it to prompt the user for options:
```
echo "Yes\nNo" | dmenu-mac -p "Are you sure?"
Yes
```
As with the app list, if nothing matches (or with shift-enter), the typed text is printed instead. Pass `--no-custom` to only accept items from the list.
Pressing Esc prints nothing and exits with status 1, like dmenu.

## Installation

dmenu-mac can be installed with [brew](https://brew.sh/) running:

```
brew install dmenu-mac
```

Optionally, you can download it [here](https://github.com/oNaiPs/dmenu-mac/releases).

NOTE: the releases are not signed yet, use it at your own risk. I'll take care of that as soon as we can assess the number of people interested in the project.

*macOS 13.5 or greater required.

## Features

- Uses fuzzy search
- Configurable global hotkey
- Doesn't steal focus: the app you were in stays frontmost and gets the keyboard back instantly
- Menu bar icon and optional Launch at Login
- Top or bottom placement
- Multi-display support
- Not dependant on spotlight indexing
- Opens System Settings panes (e.g. Displays, Network, Accessibility)

# Development

```sh
xcodebuild -skipPackagePluginValidation -skipMacroValidation \
  -project dmenu-mac.xcodeproj -scheme dmenu-mac -configuration Debug test
# single test: add -only-testing:dmenu-macTests/SearchServiceTests[/testName]

swiftlint --strict   # CI fails on warnings
```

`-skipPackagePluginValidation` is required because SwiftLint runs as an Xcode build plugin.

# Pull requests
Any improvement/bugfix is welcome.

# Authors

[@onaips](https://twitter.com/onaips)
