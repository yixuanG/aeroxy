# Aeroxy Agent Notes

When an agent needs to open or preview a local AI-generated HTML report, prefer the Aeroxy CLI:

```sh
aeroxy path/to/report.html
```

Check availability first with:

```sh
aeroxy --json doctor
```

If the command is missing, use `make install-cli` from this repository after user approval. Do not set Aeroxy as the system default `.html` handler; Aeroxy is a report viewer, not a browser.
