# Changelog

All notable changes to Workdeck are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Status tab shows a TAILNET row for `tailscale serve` shares: the `ts.net` URL, the app behind it, and whether it is running.
- Links to each repository's page on GitHub (or any Git host) from its `origin` remote, in the Git Repos tab and as a REPO row in the Status tab.
- PostgreSQL Homebrew services at the top of the Status tab, with their state, port, and start and stop buttons.
- A `tailnet` section in `.workdeck.json` lists apps that share one forwarded port. Each appears under LOCAL, and starting one stops the app that holds the port.

## [1.3.0] - 2026-09-29

### Added

- Status tab that shows the prod and dev URLs of each project from a `.workdeck.json` file, whether its portless apps are running, and which database environment each running backend is connected to.
- Run and stop buttons for portless apps in the Status tab, with each app's output logged to `~/Library/Logs/Workdeck`.
- Apps that exit before their route appears, or do not start within 30 seconds, are marked Failed with a link to their log.
- The Status tab explains how to add environment links when nothing is configured.
- Package scripts run with the package manager from the nearest lockfile (bun, pnpm, yarn, or npm).
- Portless state is read from `~/.portless` or `/tmp/portless`, including the proxy port, HTTPS setting, and TLD; unreadable routes are skipped.
- A 48-second intro video generated from code (`video/`), saved to `docs/intro.mp4`.
- Edit Environment Links… in the row context menu creates and opens `.workdeck.json`.

### Notes

- Run and database detection rely on portless 0.15 state files, `lsof`, and your login shell `PATH`. Database environments are a best guess from host names and `.env` files.

## [1.2.0] - 2026-09-13

### Added

- The menu bar can show the workspace or folder of the focused VS Code window, so it is clear which project you are in when many VS Code windows are open.
- Settings menu in the popup footer to show the menu bar as Icon, Text, or Icon and Text.
- The name comes from the VS Code window title and is matched against scanned projects, so titles with a profile name still resolve correctly.
- The label fits the full project name. A Name Length option in the gear menu shortens long names to 24, 16, or 12 characters when a crowded menu bar hides the item.

### Notes

- Text modes need Accessibility access to read VS Code window titles. Workdeck asks for it when a text mode is selected.

## [1.1.1] - 2026-09-13

### Fixed

- The list now rescans every time the popup opens. Before, only the first open scanned, so new projects and root folder changes needed Rescan or an app restart.

## [1.1.0] - 2026-09-13

### Added

- Git Repos tab that lists every Git repository under the root folders, including repositories that belong to a workspace file.
- Branch name, uncommitted file count, and commits ahead of or behind the upstream for each repository, loaded in the background with `git status`.
- Search and Return-to-open work on whichever tab is selected.
- Multiple root folders. A folder menu next to the search field shows every root or a single one, adds folders with a folder picker, and removes them.
- Section titles include the root folder name when several roots are shown together.

### Changed

- Root folders are stored in the `ScanRoots` array. A `ScanRoot` value from 1.0.0 is still used until a root is first added or removed.
- Root folder changes take effect the next time the popup opens, without restarting the app.

## [1.0.0] - 2026-09-13

First public release.

### Added

- Menu bar popup that lists every VS Code project under a scan root, with no Dock icon.
- Automatic discovery of `.code-workspace` files and Git repositories, up to three folder levels deep.
- Duplicate removal: repositories already listed in a workspace file's `folders` are hidden.
- Grouping by top-level folder under the scan root.
- Search as you type, Return to open the first match, and click to open any row.
- Opening through the VS Code app bundle with `NSWorkspace`, so the `code` CLI is not required.
- Rescan button, and an automatic rescan every time the popup opens.
- Configurable scan root through `defaults write com.kijtisakp.Workdeck ScanRoot <path>`, defaulting to `~/Developer`.
- App icon, monochrome menu bar icon that adapts to light and dark menu bars, and version number in the popup footer.
- `scripts/build-app.sh` to build, sign ad hoc, install to `/Applications`, and launch the app.

### Known limitations

- The release binary is built for Apple Silicon only.
- The app is signed ad hoc and not notarized, so macOS Gatekeeper blocks the first launch of a downloaded copy.
- Changing `ScanRoot` takes effect after quitting and reopening the app.

[1.3.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.3.0
[1.2.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.2.0
[1.1.1]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.1.1
[1.1.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.1.0
[1.0.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.0.0
