# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 在此專案中工作時的指引。

## 專案概述

FolderSync 是原生 macOS 選單列應用程式（Swift 5.10 + SwiftUI），透過 [unison](https://github.com/bcpierce00/unison) CLI 實現即時雙向資料夾同步。主要用途：在 Google Drive 與 iCloud 之間同步 Obsidian vault。

## 建置與執行

```bash
# 建置（SPM，macOS 14+）
swift build

# 從原始碼執行（語言檔從原始碼目錄載入）
swift run FolderSync

# Release 建置
swift build -c release
```

目前沒有測試目標。沒有 Makefile 或建置腳本，全部使用 Swift Package Manager（`Package.swift`）。

## 架構

**進入點：** `FolderSync/FolderSyncApp.swift` — 選單列 accessory 應用程式，包含兩個 Scene：`MenuBarExtra`（常駐顯示）和設定 `Window`。

### 分層結構

```
FolderSyncApp
├── ViewModels/
│   ├── SyncManager     — @Observable @MainActor 調度器；擁有 AppState 及所有 Service
│   └── AppState        — @Observable 全域狀態（同步配對、狀態、日誌、設定）
├── Services/
│   ├── UnisonService        — actor；組建 CLI 參數、啟動 unison Process、解析結果
│   ├── FileWatcherService   — FSEvents C API 監視器，含 2 秒 debounce
│   ├── PersistenceService   — JSON 讀寫至 ~/Library/Application Support/FolderSync/
│   ├── ICloudHelper         — 偵測 iCloud 路徑，執行 `brctl download` 下載佔位檔
│   └── UpdateService        — actor；透過 GitHub Releases API 檢查更新 + DMG 下載安裝
├── Models/
│   ├── SyncPair        — 來源/目的路徑、方向、排除規則、啟用狀態
│   ├── SyncStatus      — 列舉：idle、watching、syncing、error、paused
│   ├── L10n            — 動態 JSON 多語系載入器（en-US、zh-TW），從 Resources/Locales/ 讀取
│   └── Theme           — 語意色彩、字型、狀態對應圖示映射
└── Views/
    ├── MenuBarView / MenuBarPairRow
    └── 設定視窗（4 頁籤側邊欄）
        ├── SyncPairsListView → SyncPairRow、SyncPairEditView
        ├── SyncLogView
        ├── GeneralSettingsView
        └── BackupSettingsView
```

### 關鍵資料流

1. **檔案變更 → 同步：** FSEvents → 2 秒 debounce → `SyncManager.triggerSync()` → iCloud 佔位檔下載（如需要）→ `UnisonService.sync()` → 更新 `AppState` → UI 重新渲染
2. **並行安全：** `SyncManager.syncLocks: Set<UUID>` 防止同一配對的並行同步。`UnisonService` 和 `UpdateService` 為 `actor` 型別。
3. **持久化：** 設定與日誌以 JSON 格式儲存於 `~/Library/Application Support/FolderSync/`，日誌上限 500 筆。

### Unison 結束碼

- 0 = 成功、1 = 部分完成（有衝突）、2 = 連線錯誤、3 = 中止
- 衝突檔案重新命名為 `{name}.conflict.{ext}`

## 多語系

以 JSON 為基礎（`FolderSync/Resources/Locales/*.json`）。新增語言：複製 `en-US.json`、翻譯所有值、放入 `Locales/` 資料夾。回退鏈：當前語言 → en-US → 原始 key。

## 建置產出物

`build/` 包含預建置的 DMG、`.app` 套件和 `AppIcon.icns`。此目錄已加入 gitignore。

## 執行時依賴

需要安裝 `unison`（`brew install unison`）。應用程式從使用者設定中解析其路徑（預設：Homebrew 安裝位置）。
