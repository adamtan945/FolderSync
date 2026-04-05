# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
