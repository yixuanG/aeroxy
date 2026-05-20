# Aeroxy

Aeroxy is a tiny macOS HTML report viewer for AI-generated local reports. It renders with WebKit, keeps the app shape closer to a lightweight viewer than a browser, and sends web links to the system default browser.

## Product Shape

- Local HTML viewer, not a browser: no address bar, bookmarks, or navigation chrome.
- WebKit rendering for Safari-quality HTML, CSS, and JavaScript.
- File links stay in Aeroxy; `http://` and `https://` main-frame navigations open in the default browser.
- Recent local HTML files are available from the History menu.
- Multiple local HTML files can be kept open with tabs.
- Sandboxed read-only file access with security-scoped bookmarks for history.
- Native SwiftUI interface with Tahoe Liquid Glass when available, and material fallback on older macOS versions.

## Requirements

- macOS 15 or newer to run.
- Xcode 26 or newer to build with the current project settings.
- Swift 6.

## Build In Xcode

1. Open `Aeroxy.xcodeproj`.
2. Select the `Aeroxy` scheme.
3. Build and run.

## Build A Local DMG

```sh
Scripts/build-dmg.sh
```

The script keeps derived data and packaging artifacts inside `.build/` so the project does not need global package installs.

For public distribution, sign and notarize the app with a Developer ID certificate before publishing the DMG.

## Repository Notes

The project is intentionally dependency-light:

- SwiftUI for the shell UI.
- WebKit for rendering.
- AppKit only where macOS integration is needed, such as file panels and default-browser handoff.

## License

MIT

