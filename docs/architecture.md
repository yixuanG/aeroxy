# Aeroxy Architecture

Aeroxy is a macOS SwiftUI app with a small AppKit and WebKit bridge.

## Core Pieces

- `AppModel` owns tabs, selected state, open-panel flow, and history opening.
- `HistoryStore` persists recent local files with security-scoped bookmarks.
- `HTMLTab` keeps per-tab file access alive while a file is open.
- `WebView` wraps `WKWebView` and owns the navigation policy.
- `URLPolicy` keeps file-vs-external URL classification testable and isolated.
- `AeroxyCLI` is a companion command-line target that delegates local HTML files to the app through LaunchServices.

## Viewer Boundary

Aeroxy should open local HTML files and render them well. It should not become a browser.

Allowed:

- Open local `.html`, `.htm`, and `.xhtml` files.
- Switch between local files with tabs.
- Use the History menu for recently opened local files.
- Follow local HTML links inside Aeroxy.
- Open web links in the default browser.
- Open files from CLI workflows with `aeroxy report.html`.

Avoid:

- Address bars.
- Back/forward controls.
- Web bookmarks.
- Search-provider features.
- Storing web browsing history.

## File Access

When the user selects a file, Aeroxy starts a read-only security scope and keeps it alive through the `HTMLTab` lifetime. The WebKit load call uses the file's parent directory as `allowingReadAccessTo` so relative report assets work without granting broad filesystem access.

Main-frame local HTML links update the current tab by default. Local HTML links that request a new window open as a new tab. Local non-HTML main-frame links are handed to the system instead of expanding Aeroxy into a general file browser.

## CLI Entry

The `aeroxy` tool validates local HTML paths and then calls `/usr/bin/open` against the nearby `Aeroxy.app` when running from a build directory or against the registered `dev.yixuanguo.aeroxy` bundle identifier when installed. It does not parse or render HTML itself.

## UI Layer

The window uses native macOS materials, hidden title chrome, and a compact tab strip. On macOS 26 and newer, Aeroxy uses SwiftUI glass APIs where available. Older systems fall back to standard material backgrounds.
