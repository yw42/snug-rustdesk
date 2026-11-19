// App 资源库的系统一侧：本机装了哪些 App、哪些在跑、App 的图标，启动与唤回、新建窗口、退出。
// 窗口归 WindowService；两边读出来的东西由 Snug 里的 AppCatalog 汇成界面唯一的数据源。
// 都是公开接口，不需要额外权限（实测 terminate 不弹授权）；新建窗口按的是菜单项，要辅助功能权限
import AppKit
import ApplicationServices
import SnugCore

public final class AppService: AppControl {
    /// 找 App 的目录（含一层子目录，比如「应用程序/实用工具」、Setapp）。不用 Spotlight：索引关了或没建好就会缺
    static let directories = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
    /// 不在这些目录里、但人人都用的：访达
    static let extras = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]

    private let queue = DispatchQueue(label: "com.yw42.snug-rustdesk.apps", qos: .userInitiated)

    public init() {}

    // MARK: 读

    /// 本机装着的 App：常规目录里有 bundle ID 的 .app，排除菜单栏、后台 App 和 Snug 自己。
    /// 一百个左右，读 Info.plist 不到 0.3 秒（实测），放在后台做
    public func installed() async -> [InstalledApp] {
        await run {
            let own = Bundle.main.bundleIdentifier
            return (Self.directories.flatMap(Self.bundles) + Self.extras).compactMap { url -> InstalledApp? in
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, id != own else { return nil }
                let info = bundle.infoDictionary ?? [:]
                guard !Self.flag(info["LSUIElement"]), !Self.flag(info["LSBackgroundOnly"]) else { return nil }
                let app = AppInfo(bundleID: id, name: Self.displayName(url), path: url.path)
                return InstalledApp(app, english: (info["CFBundleName"] as? String) ?? app.name)
            }
        }
    }

    /// 在跑的普通 App（有 Dock 图标的），不含 Snug 自己；窗口由 WindowService 补上
    @MainActor
    public func running() -> [RunningApp] {
        Self.regular().compactMap { app in Self.info(for: app).map { RunningApp(pid: app.processIdentifier, app: $0, windows: []) } }
    }

    /// 普通 App（有 Dock 图标的），不含 Snug 自己。窗口快照也只拍这些。
    /// 刚退出的 App 还会在 runningApplications 里留一会儿（等主线程处理完通知），按 isTerminated 去掉
    @MainActor
    static func regular() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0 != NSRunningApplication.current
        }
    }

    /// 找不到 .app 时给系统的通用 App 图标
    @MainActor
    public static func icon(for app: AppInfo) -> NSImage {
        if let path = app.path ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)?.path {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }

    /// 名字和装着的一致：按 Snug 的本地化取显示名（中文界面下系统 App 是「备忘录」），没有路径时用进程报的名字
    static func info(for app: NSRunningApplication) -> AppInfo? {
        guard let id = app.bundleIdentifier else { return nil }
        let name = app.bundleURL.map(displayName) ?? app.localizedName ?? id
        return AppInfo(bundleID: id, name: name, path: app.bundleURL?.path)
    }

    // MARK: AppControl

    public func pid(of app: AppInfo) async -> Int32? {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first?.processIdentifier
    }

    public func pids(bundleID: String) async -> [Int32] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier)
    }

    public func open(_ app: AppInfo) async -> Int32? {
        guard let url = app.path.map(URL.init(fileURLWithPath:)) ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
        else { return nil }
        do {
            return try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()).processIdentifier
        } catch {
            Log.error("打开 \(url.path) 失败：\(error)")
            return nil
        }
    }

    public func newWindow(pid: Int32) async -> Bool {
        await run {
            let items = AX.menuCommands(pid: pid)
            guard let index = NewWindowMenu.pick(items.map(\.command)) else { return false }
            let command = items[index].command
            Log.info("新建窗口：按菜单项「\([command.parent, command.title].compactMap { $0 }.joined(separator: " › "))」（pid \(pid)）")
            return AX.press(items[index].element)
        }
    }

    public func quit(pid: Int32) async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return true }
        guard app.terminate() else {
            Log.warn("退出请求没发出去（pid \(pid)）")
            return false
        }
        return true
    }

    public func forceQuit(pid: Int32) async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return true }
        guard app.forceTerminate() else {
            Log.warn("强制退出请求没发出去（pid \(pid)）")
            return false
        }
        return true
    }

    public func isRunning(pid: Int32) async -> Bool {
        NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated } ?? false
    }

    // MARK: 内部

    private static func bundles(in directory: String) -> [URL] {
        let fm = FileManager.default
        let top = (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: [.isDirectoryKey],
                                                options: [.skipsHiddenFiles])) ?? []
        return top.flatMap { url -> [URL] in
            if url.pathExtension == "app" { return [url] }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return [] }
            return ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
                .filter { $0.pathExtension == "app" }
        }
    }

    /// 访达隐藏扩展名时（默认）displayName 已经去掉了 .app：只去结尾的 .app，名字本身带点的（zoom.us）不截
    private static func displayName(_ url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    private static func flag(_ value: Any?) -> Bool {
        (value as? Bool) == true || (value as? String) == "1" || (value as? NSNumber)?.boolValue == true
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }
}
