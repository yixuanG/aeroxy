# Aeroxy Architecture

Aeroxy is a macOS SwiftUI app with a small AppKit and WebKit bridge.

## Core Pieces

- `AppModel` owns tabs, selected state, open-panel flow, and history opening.
- `HistoryStore` persists recent local files with security-scoped bookmarks.
- `HTMLTab` keeps per-tab file access alive while a file is open.
- `WebView` wraps `WKWebView` and owns the navigation policy.
- `URLPolicy` keeps file-vs-external URL classification testable and isolated.

## Viewer Boundary

Aeroxy should open local HTML files and render them well. It should not become a browser.

Allowed:

- Open local `.html`, `.htm`, and `.xhtml` files.
- Switch between local files with tabs.
- Use the History menu for recently opened local files.
- Follow local file links inside Aeroxy.
- Open web links in the default browser.

Avoid:

- Address bars.
- Back/forward controls.
- Web bookmarks.
- Search-provider features.
- Storing web browsing history.

## File Access

When the user selects a file, Aeroxy starts a read-only security scope and keeps it alive through the `HTMLTab` lifetime. The WebKit load call uses the file's parent directory as `allowingReadAccessTo` so relative report assets work without granting broad filesystem access.

## UI Layer

The window uses native macOS materials, hidden title chrome, and a compact tab strip. On macOS 26 and newer, Aeroxy uses SwiftUI glass APIs where available. Older systems fall back to standard material backgrounds.

