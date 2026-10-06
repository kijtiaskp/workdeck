# Workdeck

Native macOS menu bar app (SwiftUI `MenuBarExtra`, macOS 14+, Swift 5.10 tools, no dependencies). Lists VS Code workspaces and Git repositories, shows Git status, and a Status tab with environment links, portless apps, and the database each running app uses.

## Layout
- `Sources/Workdeck/Models/` — value types (`Workspace`, `GitRepository`, `ProjectStatus`, `EnvironmentLinks`, …).
- `Sources/Workdeck/Services/` — scanning, Git, portless, process control. No UI code.
- `Sources/Workdeck/Views/` — SwiftUI views. `LauncherView` owns all popup state and the three tabs.
- `Resources/` — `Info.plist` (version lives here), icons.
- `docs/` — landing page, `demo.gif`, `intro.mp4`, `intro-poster.jpg`.
- `video/` — code-generated intro video (see below).

## Build
- `./scripts/build-app.sh` — release build, wraps `Workdeck.app`, ad-hoc signs, installs to `/Applications`, relaunches.
- Without Xcode, the macOS 27 SDK fails with `SwiftUIMacros plugin not found`; the script falls back to the Command Line Tools macOS 26.5 SDK. For a plain build use `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`.
- No test target. Do not add tests unless asked.

## Status tab data sources
- Environment links: `.workdeck.json` in the project folder (`ProjectLinksFile`). Schema: `{"environments": {"<env>": {"<label>": "<url>"}}}`.
- Portless apps: `portless.json` or `package.json` scripts calling `portless` (`PortlessAppScanner`), plus live routes matched to a project by the portless process cwd.
- Portless state: `~/.portless` or legacy `/tmp/portless` — `routes.json`, `proxy.port`, `proxy.tls`, `proxy.tld` (`Portless`). `routes.json` is internal to portless (tested with 0.15); decode leniently.
- Tailnet: `tailscale serve status --json` (`TailscaleServe`). A `tailnet` section in `.workdeck.json` (`port` + `apps` with `folder`/`path`/`script`) lists apps that share one forwarded port; Run frees the port first. Workdeck never edits `tailscale serve`.
- PostgreSQL: `brew services list --json` filtered to `postgresql*`, port from `<prefix>/var/<formula>/postgresql.conf` (`HomebrewServices`); start/stop via `brew services`.
- Database: `lsof` on the process listening on the route port and its descendants, matched against environment link hosts, then `.env*` database hosts (`DatabaseConnectionDetector`). Heuristic by design.
- Run/Stop: `$SHELL -lc "exec portless"` or `<package manager> run <script>` in the app folder; logs in `~/Library/Logs/Workdeck/<name>.log`, shown with `tail -f` via a `.command` file in Terminal (`PortlessAppController`).

## Conventions
- Match existing style: small `enum` namespaces for services, `struct` models, async `ProcessRunner` for subprocesses, no force unwraps.
- README and CHANGELOG are English. Add user-visible changes under `## [Unreleased]` in `CHANGELOG.md`.
- Conventional commits, English, one concern per commit, no `Co-Authored-By`.

## Intro video (`video/`)
- `scene.js` (three.js + GSAP, deterministic `renderFrame(t)` via a paused timeline) + `index.html` overlay text.
- `render.mjs` serves the folder, drives headless Chrome, screenshots every frame to `frames/`. `node render.mjs 3.5 26` renders stills to `out/stills/` for review.
- `music.py` (numpy) synthesizes the soundtrack; event times mirror the timeline in `scene.js` — keep them in sync when retiming.
- `build.sh` renders, synthesizes, and muxes to `docs/intro.mp4` (loudnorm −14 LUFS). Keep the background free of per-frame noise; animated grain inflated the file past GitHub's 100 MB limit.
