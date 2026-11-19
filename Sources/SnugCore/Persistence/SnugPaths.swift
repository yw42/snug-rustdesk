// 数据目录与各状态文件路径的唯一来源。测试里换成临时目录
import Foundation

public struct SnugPaths: Equatable, Sendable {
    public let dataDirectory: URL
    public let logFile: URL

    public init(dataDirectory: URL, logFile: URL) {
        self.dataDirectory = dataDirectory
        self.logFile = logFile
    }

    /// ~/Library/Application Support/SnugRustDesk/ 与 ~/Library/Logs/SnugRustDesk.log
    public static var standard: SnugPaths {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return SnugPaths(
            dataDirectory: library.appendingPathComponent("Application Support/SnugRustDesk", isDirectory: true),
            logFile: library.appendingPathComponent("Logs/SnugRustDesk.log"))
    }

    /// 用户设置
    public var config: URL { file("config.json") }
    /// 每块屏一份还原账（placed/<屏 id>.json）：窗口放上去之前写，放回原位才删；崩溃后下次启动按它还原
    public var placedRecords: URL { dataDirectory.appendingPathComponent("placed", isDirectory: true) }
    public func placedRecord(for screen: ScreenID) -> URL { placedRecords.appendingPathComponent("\(screen.rawValue).json") }
    /// 电脑屏上挪过来的窗口一个一份（placed/<屏 id>~<pid>-<窗口号>.json）：和触屏的账同一个目录、同一种格式，
    /// 启动时按「目录里一个文件一笔账」逐笔还原（DeskSet.recover），降级回不认识它的版本也照样还
    public func broughtRecord(for screen: ScreenID, window: WindowKey) -> URL {
        placedRecord(for: ScreenID("\(screen.rawValue)~\(window.pid)-\(window.id)"))
    }
    /// 2.5 及以前只有一块手机屏时的还原账。启动时还在就挪成那块屏的账（placed/phone.json），按它还原
    public var legacyPlacedRecord: URL { file("phone-screen.json") }
    /// 每个 App 在手机、平板屏上记住的字号级数
    public var zoomBook: URL { file("zoom.json") }
    /// 留下的账：在 Snug 屏上被 Snug 之外关掉的窗口，等它回来时按账放回原位、缩回字号
    public var leftBehind: URL { file("left-behind.json") }

    private func file(_ name: String) -> URL { dataDirectory.appendingPathComponent(name) }
}
