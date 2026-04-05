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
│   ├── UnisonService        — actor；組建 CLI 參數、啟動 unison Process、解析結果（用 readabilityHandler 非同步讀 pipe 避免死鎖）
│   ├── FileWatcherService   — FSEvents C API 監視器，含 2 秒 debounce
│   ├── PersistenceService   — JSON 讀寫至 ~/Library/Application Support/FolderSync/
│   ├── CloudFileHelper       — 偵測雲端佔位檔（iCloud、Google Drive 等），用 macOS ubiquitous item API 下載
│   ├── FileLogger           — 檔案日誌服務，寫入 Logs/{YYYY-MM-DD-HH}.log，自動清除 30 天前日誌
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

1. **檔案變更 → 同步：** FSEvents → 2 秒 debounce → `SyncManager.triggerSync()` → 雲端佔位檔下載（如需要）→ `UnisonService.sync()` → 更新 `AppState` → UI 重新渲染
2. **並行安全：** `SyncManager.syncLocks: Set<UUID>` 防止同一配對的並行同步。`UnisonService` 和 `UpdateService` 為 `actor` 型別。
3. **持久化：** 設定與 UI 日誌以 JSON 格式儲存於 `~/Library/Application Support/FolderSync/`，UI 日誌上限 500 筆。偵錯日誌另存於 `Logs/{YYYY-MM-DD-HH}.log`，保留 30 天。

### Unison 結束碼

- 0 = 成功、1 = 部分完成（有衝突）、2 = 連線錯誤、3 = 中止
- 衝突檔案重新命名為 `{name}.conflict.{ext}`

## 多語系

以 JSON 為基礎（`FolderSync/Resources/Locales/*.json`）。新增語言：複製 `en-US.json`、翻譯所有值、放入 `Locales/` 資料夾。回退鏈：當前語言 → en-US → 原始 key。

## 建置產出物

`build/` 包含預建置的 DMG、`.app` 套件和 `AppIcon.icns`。此目錄已加入 gitignore。

## Release 打包流程

**版號必須同步更新 `FolderSync/Services/UpdateService.swift:8` 的 `currentVersion`**，否則 app 的 check update 功能會失效。

```bash
# 1. Release 編譯
swift build -c release

# 2. 更新 Info.plist 版號（build/FolderSync.app/Contents/Info.plist）
#    CFBundleVersion + CFBundleShortVersionString

# 3. 組裝 .app bundle
cp .build/arm64-apple-macosx/release/FolderSync build/FolderSync.app/Contents/MacOS/
mkdir -p build/FolderSync.app/Contents/Resources/Resources/Locales
cp FolderSync/Resources/Locales/*.json build/FolderSync.app/Contents/Resources/Resources/Locales/
cp FolderSync/Resources/AppIcon.icns build/FolderSync.app/Contents/Resources/

# 4. 清除 xattr + ad-hoc 簽名
xattr -cr build/FolderSync.app
codesign --force --deep --sign - build/FolderSync.app
codesign -vv build/FolderSync.app  # 驗證

# 5. 製作 DMG
rm -rf build/dmg_staging
mkdir -p build/dmg_staging
ln -s /Applications build/dmg_staging/Applications
cp -r build/FolderSync.app build/dmg_staging/
hdiutil create -volname "FolderSync" -srcfolder build/dmg_staging -ov -format UDZO build/FolderSync-X.Y.Z.dmg
fileicon set build/FolderSync-X.Y.Z.dmg build/AppIcon.icns

# 6. 上傳至 GitHub Release
gh release create vX.Y.Z build/FolderSync-X.Y.Z.dmg --title "vX.Y.Z" --notes "..."
```

## 已知限制

- **MenuBarExtra**：macOS 的 `.menu` 樣式只支援標準選單元件（Button、Text、Divider），不支援自訂 SwiftUI 視圖（Capsule、背景色等）。狀態顯示需用純文字 + SF Symbol。
- **Pipe 死鎖風險**：`Process` + `Pipe` 在大量輸出時必須用 `readabilityHandler` 非同步讀取，否則 pipe buffer（64KB）滿時會死鎖。已在 `UnisonService` 中修正。

## 執行時依賴

需要安裝 `unison`（`brew install unison`）。應用程式從使用者設定中解析其路徑（預設：Homebrew 安裝位置）。
