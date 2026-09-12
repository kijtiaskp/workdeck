# Changelog

All notable changes to Workdeck are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

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

[1.1.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.1.0
[1.0.0]: https://github.com/kijtiaskp/workdeck/releases/tag/v1.0.0
