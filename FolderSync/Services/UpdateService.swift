import Foundation
import AppKit

// MARK: - 自動更新服務

/// 透過 GitHub Releases API 檢查新版本、下載 DMG、安裝更新
actor UpdateService {
    static let currentVersion = "1.2.0"
    static let repo = "adamtan945/FolderSync"

    // MARK: - GitHub Release 資料結構

    struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    struct AssetCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    // MARK: - 檢查更新

    /// 檢查 GitHub 是否有新版本，回傳版本號與 DMG 下載 URL
    func checkForUpdate() async throws -> (version: String, downloadURL: URL)? {
        let urlString = "https://api.github.com/repos/\(Self.repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: data)

        // 去掉 "v" 前綴取得版本號
        let remoteVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        guard isNewer(remoteVersion, than: Self.currentVersion) else {
            logInfo("[UpdateService] 已是最新版本 (\(Self.currentVersion))")
            return nil
        }

        // 找到 DMG asset
        guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
              let downloadURL = URL(string: dmgAsset.browserDownloadUrl) else {
            logWarn("[UpdateService] 新版 \(remoteVersion) 無 DMG 下載連結")
            return nil
        }

        logInfo("[UpdateService] 發現新版本: \(remoteVersion)")
        return (remoteVersion, downloadURL)
    }

    // MARK: - 版本比較

    /// Semantic Versioning 比較：remote 是否比 local 新
    func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    // MARK: - 下載更新

    /// 下載 DMG 到暫存目錄，透過 delegate 回報進度
    func downloadUpdate(url: URL, progress: @Sendable @escaping (Double) -> Void) async throws -> URL {
        let destinationDir = FileManager.default.temporaryDirectory
        let destinationURL = destinationDir.appendingPathComponent("FolderSync-update.dmg")

        // 清除舊的下載檔
        try? FileManager.default.removeItem(at: destinationURL)

        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

        let totalBytes = response.expectedContentLength
        var receivedBytes: Int64 = 0
        var data = Data()
        if totalBytes > 0 {
            data.reserveCapacity(Int(totalBytes))
        }

        for try await byte in asyncBytes {
            data.append(byte)
            receivedBytes += 1
            if totalBytes > 0 && receivedBytes % 102400 == 0 {
                let fraction = Double(receivedBytes) / Double(totalBytes)
                progress(min(fraction, 1.0))
            }
        }

        progress(1.0)
        try data.write(to: destinationURL, options: .atomic)
        logInfo("[UpdateService] DMG 下載完成: \(destinationURL.path)")
        return destinationURL
    }

    // MARK: - 安裝更新

    /// 掛載 DMG、複製 .app、卸載、重啟
    func installUpdate(dmgPath: URL) async throws {
        let mountPoint = "/tmp/FolderSync-mount"

        // 清除舊掛載點
        try? FileManager.default.removeItem(atPath: mountPoint)

        // 1. 掛載 DMG
        let attachProcess = Process()
        attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProcess.arguments = ["attach", dmgPath.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]
        try attachProcess.run()
        attachProcess.waitUntilExit()

        guard attachProcess.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }

        // 2. 找到 .app
        let appSourcePath = "\(mountPoint)/FolderSync.app"
        guard FileManager.default.fileExists(atPath: appSourcePath) else {
            // 卸載再丟錯誤
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint, "-quiet"]
            try? detach.run()
            detach.waitUntilExit()
            throw UpdateError.appNotFound
        }

        // 3. 決定安裝位置
        let installPath = "/Applications/FolderSync.app"

        // 4. 移除舊版、複製新版
        try? FileManager.default.removeItem(atPath: installPath)
        try FileManager.default.copyItem(atPath: appSourcePath, toPath: installPath)

        // 5. 卸載 DMG
        let detachProcess = Process()
        detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detachProcess.arguments = ["detach", mountPoint, "-quiet"]
        try detachProcess.run()
        detachProcess.waitUntilExit()

        // 6. 清除暫存 DMG
        try? FileManager.default.removeItem(at: dmgPath)

        logInfo("[UpdateService] 安裝完成，準備重新啟動")

        // 7. 重新啟動
        await MainActor.run {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [installPath]
            try? task.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - 錯誤

    enum UpdateError: LocalizedError {
        case mountFailed
        case appNotFound

        var errorDescription: String? {
            switch self {
            case .mountFailed: return "無法掛載 DMG"
            case .appNotFound: return "DMG 中找不到 FolderSync.app"
            }
        }
    }
}
