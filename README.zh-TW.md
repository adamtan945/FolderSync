[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)
[![Swift](https://img.shields.io/badge/Swift-5.10-F05138.svg)](https://swift.org/)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md)
[![Changelog](https://img.shields.io/badge/changelog-CHANGELOG.md-orange.svg)](CHANGELOG.md)

# FolderSync

原生 macOS Menu Bar 即時雙向資料夾同步 App，基於 [unison](https://github.com/bcpierce00/unison) 同步引擎。

最初為了在 Google Drive 與 iCloud 之間同步 Obsidian Vault 而開發，但適用於任何資料夾配對。

## 功能特色

- **即時同步** — 基於 FSEvents 的檔案監控，2 秒 debounce
- **雙向與單向** — 每個配對可獨立選擇同步方向
- **多組同步配對** — 管理任意數量的資料夾配對
- **iCloud 支援** — 自動下載 iCloud 佔位檔案
- **衝突處理** — 保留較新檔案，舊版備份為 `{name}.conflict.{ext}`
- **排除規則** — 全域 + 個別配對，內建 17 種常見預設
- **同步日誌** — 可搜尋、可篩選、持久化儲存（最多 500 筆）
- **雙語介面** — 英文與繁體中文，支援語系擴充
- **匯出/匯入** — 以 JSON 備份及還原所有設定
- **登入啟動** — 靜默常駐 Menu Bar

## 系統需求

- macOS 14 (Sonoma) 或更新版本
- 透過 Homebrew 安裝 [unison](https://github.com/bcpierce00/unison)

## 安裝方式

### 方式一：DMG 安裝（推薦）

1. 從 [Releases](https://github.com/adamtan945/FolderSync/releases) 下載最新的 `.dmg`
2. 打開 DMG，將 **FolderSync** 拖入「應用程式」資料夾
3. 啟動 FolderSync，圖示會出現在 Menu Bar
4. 若尚未安裝 unison：
   ```bash
   brew install unison
   ```

### 方式二：從原始碼編譯

```bash
# 複製專案
git clone https://github.com/adamtan945/FolderSync.git
cd FolderSync

# 安裝 unison
brew install unison

# 編譯並執行
swift build
swift run FolderSync
```

> **注意**：透過 `swift run` 執行時，App 會從原始碼目錄讀取語系檔。若需完整 `.app` 體驗，請使用 DMG 安裝。

## 使用方式

1. 點擊 Menu Bar 上的 FolderSync 圖示
2. 開啟**設定**（⌘,）
3. 前往**同步配對** → **新增同步配對**
4. 選擇來源與目的資料夾
5. 選擇同步方向（單向 → 或雙向 ⇄）
6. FolderSync 會自動開始監控並同步

## 新增語言

FolderSync 使用 JSON 語系檔。新增語言步驟：

1. 複製 `FolderSync/Resources/Locales/en-US.json`
2. 重新命名為你的語系（如 `ja-JP.json`）
3. 翻譯所有值，將 `"languageName"` 設為原生語言名稱（如 `"日本語"`）
4. 放入 `Locales/` 資料夾
5. 點擊語言選單旁的重新載入按鈕（↻）

## 技術架構

| 元件 | 技術 |
|------|------|
| 語言 | Swift 5.10 + SwiftUI |
| 同步引擎 | [unison](https://github.com/bcpierce00/unison) CLI |
| 檔案監控 | FSEvents C API |
| iCloud | `brctl download` |
| 資料儲存 | JSON，位於 `~/Library/Application Support/FolderSync/` |
| 介面 | MenuBarExtra + NavigationSplitView |

## 授權

[MIT](LICENSE)
