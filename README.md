[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)
[![Swift](https://img.shields.io/badge/Swift-5.10-F05138.svg)](https://swift.org/)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![繁體中文](https://img.shields.io/badge/lang-繁體中文-blue.svg)](README.zh-TW.md)
[![Changelog](https://img.shields.io/badge/changelog-CHANGELOG.md-orange.svg)](CHANGELOG.md)

# FolderSync

A native macOS Menu Bar app for real-time bidirectional folder synchronization, powered by [unison](https://github.com/bcpierce00/unison).

Built for syncing Obsidian vaults between Google Drive and iCloud, but works with any folder pair.

## Features

- **Real-time sync** — FSEvents-based file watching with 2-second debounce
- **Bidirectional & one-way** — Choose sync direction per pair
- **Multiple sync pairs** — Manage as many folder pairs as you need
- **iCloud support** — Automatic placeholder file materialization
- **Conflict handling** — Keeps newer file, backs up old as `{name}.conflict.{ext}`
- **Exclusion rules** — Global + per-pair, with 17 built-in presets
- **Sync log** — Searchable, filterable, persistent (up to 500 entries)
- **Bilingual UI** — English & Traditional Chinese, with drop-in language pack support
- **Export/Import** — Backup and restore all settings as JSON
- **Launch at Login** — Runs silently in the Menu Bar

## Requirements

- macOS 14 (Sonoma) or later
- [unison](https://github.com/bcpierce00/unison) installed via Homebrew

## Installation

### Option 1: DMG (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/adamtan945/FolderSync/releases)
2. Open the DMG and drag **FolderSync** to your Applications folder
3. Launch FolderSync — it will appear in the Menu Bar
4. Install unison if you haven't:
   ```bash
   brew install unison
   ```

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/adamtan945/FolderSync.git
cd FolderSync

# Install unison
brew install unison

# Build and run
swift build
swift run FolderSync
```

> **Note**: When running via `swift run`, the app resolves language files from the source directory. For a proper `.app` bundle experience, use the DMG.

## Usage

1. Click the FolderSync icon in the Menu Bar
2. Open **Settings** (⌘,)
3. Go to **Sync Pairs** → **Add Sync Pair**
4. Select source and destination folders
5. Choose sync direction (one-way → or bidirectional ⇄)
6. FolderSync will begin watching and syncing automatically

## Adding Languages

FolderSync uses JSON-based language files. To add a new language:

1. Copy `FolderSync/Resources/Locales/en-US.json`
2. Rename to your locale (e.g., `ja-JP.json`)
3. Translate all values, set `"languageName"` to the native name (e.g., `"日本語"`)
4. Place in the `Locales/` folder
5. Click the reload button (↻) next to the language picker

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.10 + SwiftUI |
| Sync Engine | [unison](https://github.com/bcpierce00/unison) CLI |
| File Watching | FSEvents C API |
| iCloud | `brctl download` |
| Persistence | JSON in `~/Library/Application Support/FolderSync/` |
| UI | MenuBarExtra + NavigationSplitView |

## License

[MIT](LICENSE)
