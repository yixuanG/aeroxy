# Contributing To Aeroxy

Thanks for taking a look at Aeroxy. The project is intentionally small: it should feel like a focused macOS viewer for local AI-generated HTML reports, not a general browser.

## Local Setup

- Install Xcode 26 or newer.
- Open `Aeroxy.xcodeproj`.
- Use the `Aeroxy` scheme.

Command-line build:

```sh
xcodebuild \
  -project Aeroxy.xcodeproj \
  -scheme Aeroxy \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build
```

Build a local unsigned DMG:

```sh
Scripts/build-dmg.sh
```

## Design Boundaries

- Keep the main window light: tabs are fine, browser chrome is not.
- Do not add an address bar, bookmarks, search engine integration, or browsing history for web URLs.
- Local file history belongs in the menu, not in the primary viewer surface.
- Main-frame web links should leave Aeroxy and open in the user's default browser.
- Keep dependencies close to zero unless a dependency removes meaningful product risk.

## Code Style

- Prefer SwiftUI for app structure and AppKit only for macOS integration points.
- Keep WebKit navigation policy in one place.
- Keep file permission handling explicit and read-only.
- Avoid global tools or package installs for routine build steps.

## Pull Requests

Please include:

- The product behavior changed.
- The build command or manual verification used.
- Any security or sandboxing impact.

