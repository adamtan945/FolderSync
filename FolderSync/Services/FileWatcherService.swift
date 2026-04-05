import Foundation
import CoreServices

// MARK: - FSEvents 檔案監控服務

/// 使用 macOS FSEvents API 遞迴監控目錄變更，附帶 debounce 防抖
final class FileWatcherService {
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let paths: [String]
    private let queue = DispatchQueue(label: "com.foldersync.fswatcher", qos: .utility)

    /// 初始化監控器
    /// - Parameters:
    ///   - paths: 要監控的目錄路徑列表
    ///   - debounceInterval: 防抖間隔（秒），預設 2 秒
    ///   - onChange: 偵測到變更後觸發的回呼
    init(paths: [String], debounceInterval: TimeInterval = 2.0, onChange: @escaping () -> Void) {
        self.paths = paths
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        stopWatching()
    }

    // MARK: - 啟動/停止監控

    /// 啟動 FSEvents 監控
    func startWatching() {
        guard stream == nil else { return }

        let pathsToWatch = paths as CFArray

        // 透過 context 傳遞 self 給 C callback
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            FileWatcherService.eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval, // latency：FSEvents 自身的合併間隔
            UInt32(
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagNoDefer
            )
        ) else {
            print("[FileWatcherService] FSEventStreamCreate 失敗")
            return
        }

        stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, queue)
        FSEventStreamStart(eventStream)

        print("[FileWatcherService] 開始監控: \(paths)")
    }

    /// 停止 FSEvents 監控
    func stopWatching() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            print("[FileWatcherService] 停止監控")
        }
    }

    // MARK: - FSEvents C Callback

    /// FSEvents 事件回呼（C function pointer，不可捕獲 Swift closure）
    private static let eventCallback: FSEventStreamCallback = {
        (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in

        guard let info = clientCallBackInfo else { return }
        let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()

        // 過濾掉我們不關心的事件
        guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

        // 忽略 .DS_Store 和 .icloud 檔案的變更（避免不必要的觸發）
        let hasRelevantChange = paths.contains { path in
            let filename = (path as NSString).lastPathComponent
            return !filename.hasSuffix(".DS_Store") && !filename.hasSuffix(".icloud")
        }

        guard hasRelevantChange else { return }

        // Debounce：取消先前排程的工作，重新排程
        watcher.debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak watcher] in
            watcher?.onChange()
        }
        watcher.debounceWorkItem = workItem
        watcher.queue.asyncAfter(
            deadline: .now() + watcher.debounceInterval,
            execute: workItem
        )
    }
}
