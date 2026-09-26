
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
2. Optionally, you can change the binding by clicking the ... on the right of the menu.
3. Type the application you want to open, hit enter to run the one selected.

### Pipes
You can make dmenu-mac part of your scripting toolbox, use it to prompt the user for options:
```
echo "Yes\nNo" | dmenu-mac -p "Are you sure?"
Yes
```

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
- Multi-display support
- Not dependant on spotlight indexing

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
