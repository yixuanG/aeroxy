# Security Policy

Aeroxy is a local HTML viewer, so its security model is deliberately narrow.

## Current Model

- The app uses macOS App Sandbox.
- Local file access is user-selected and read-only.
- Recent files use app-scoped security bookmarks.
- WebKit may load network subresources so AI-generated reports that depend on CDN assets can still render.
- Main-frame `http://`, `https://`, and other non-file navigations are handed to the system default browser.

## Non-Goals

- Aeroxy is not a hardened browser.
- Aeroxy does not try to sanitize arbitrary HTML.
- Aeroxy does not isolate every report into a separate WebKit data store yet.

## Reporting Issues

Please avoid publishing exploit details before there is a fix available. Open a private report if the repository host supports it, or contact the maintainer directly.

