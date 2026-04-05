# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-04-05

### Added
- Universal cloud placeholder download: automatically download cloud-only files before sync (supports iCloud, Google Drive, Dropbox, OneDrive, etc.)
- Uses macOS native `FileManager.startDownloadingUbiquitousItem` API instead of iCloud-specific `brctl`
- FSEvents filter for Google Drive `.tmp.drivedownload` temporary files
- File-based logging to `~/Library/Application Support/FolderSync/Logs/{YYYY-MM-DD-HH}.log` with auto-cleanup (30 days retention)
- Per-file sync logging: every synced and conflicted file is recorded in log
- Menu Bar sync pair status text (syncing/error/paused) with SF Symbol icons
- Open log folder button in Sync Log view
- Sync direction arrow animates with horizontal slide during syncing

### Fixed
- Unison pipe deadlock: large output (34k+ files) caused app to hang indefinitely during sync
- Auto-update CodingKeys bug: `browser_download_url` was not decoded correctly since v1.1.0
- Export settings button color now matches import button
- Menu Bar syncing status color changed from indigo to amber (traffic light semantics)

### 新增
- 通用雲端佔位檔下載：同步前自動下載僅存在雲端的檔案（支援 iCloud、Google Drive、Dropbox、OneDrive 等）
- 使用 macOS 原生 `FileManager.startDownloadingUbiquitousItem` API 取代 iCloud 專用的 `brctl`
- FSEvents 過濾 Google Drive `.tmp.drivedownload` 暫存檔
- 檔案日誌：寫入 `~/Library/Application Support/FolderSync/Logs/{YYYY-MM-DD-HH}.log`，自動清除超過 30 天的日誌
- 逐檔同步日誌：每筆同步的檔案和衝突檔案都會記錄到日誌
- Menu Bar 同步配對狀態文字（同步中/錯誤/已暫停），搭配 SF Symbol 圖示
- 同步日誌頁面新增「開啟日誌資料夾」按鈕
- 同步中方向箭頭改為左右滑動動畫

### 修正
- Unison pipe 死鎖：大量輸出（34,000+ 檔案）導致同步時 app 永久卡住
- 自動更新 CodingKeys bug：`browser_download_url` 從 v1.1.0 起未正確解碼
- 匯出設定按鈕顏色統一為與匯入按鈕一致
- Menu Bar 同步中狀態顏色從靛藍改為琥珀黃（紅綠燈語義）

## [1.1.1] - 2026-04-05

### Changed
- Replaced app icon with new flat folder-sync design
- Added CLAUDE.md for Claude Code project guidance

### 變更
- 更換應用程式圖示為全新扁平化資料夾同步設計
- 新增 CLAUDE.md 作為 Claude Code 專案指引

## [1.1.0] - 2026-04-05

### Added
- Auto-update via GitHub Releases API: checks for new versions on app launch
- Update notification in Menu Bar and Settings sidebar bottom
- Manual update check button in Settings sidebar
- One-click update: download DMG, install, cleanup, and restart automatically
- Version display in Settings sidebar footer

### 新增
- 透過 GitHub Releases API 自動檢查更新：啟動時偵測新版本
- Menu Bar 與設定視窗 sidebar 底部顯示更新提示
- 設定視窗 sidebar 底部手動檢查更新按鈕
- 一鍵更新：自動下載 DMG、安裝、清除暫存、重啟
- 設定視窗 sidebar 底部顯示當前版本號

## [1.0.0] - 2026-04-05

### Added
- Native macOS Menu Bar app with real-time bidirectional folder sync via unison
- Multi sync pair management (create, edit, delete, pause/resume per pair)
- One-way and bidirectional sync modes with icon-based direction picker
- FSEvents-based file watching with 2-second debounce
- iCloud placeholder file detection and automatic materialization via `brctl download`
- Conflict handling: prefer newer file, backup old as `{name}.conflict.{ext}`
- Global and per-pair exclusion rules with preset library (17 common patterns)
- Sync log with search, error filtering, and persistent storage (up to 500 entries)
- Bilingual UI: Traditional Chinese (zh-TW) and English (en-US) with dynamic language switching
- Drop-in language pack support: add `*.json` to `Locales/` folder and reload
- Launch at Login via SMAppService
- Export/Import all settings (sync pairs, general config, language) as JSON backup
- Refined Utility aesthetic inspired by Raycast/Linear with custom color system

### 新增
- 原生 macOS Menu Bar App，透過 unison 實現即時雙向資料夾同步
- 多組同步配對管理（新增、編輯、刪除、個別暫停/恢復）
- 單向與雙向同步模式，圖示化方向選擇器
- 基於 FSEvents 的檔案監控，2 秒 debounce
- iCloud 佔位檔偵測，自動透過 `brctl download` 下載實體檔案
- 衝突處理：優先保留較新檔案，舊版備份為 `{name}.conflict.{ext}`
- 全域及個別排除規則，內建 17 種常見排除預設
- 同步日誌含搜尋、錯誤篩選、持久化儲存（最多 500 筆）
- 雙語介面：繁體中文（zh-TW）與英文（en-US），支援動態語系切換
- 語系擴充：將 `*.json` 放入 `Locales/` 資料夾即可新增語言
- 登入時自動啟動（SMAppService）
- 匯出/匯入所有設定（同步配對、一般設定、語系）為 JSON 備份檔
- 精緻工具風 UI 設計，靈感來自 Raycast/Linear，自訂配色系統
