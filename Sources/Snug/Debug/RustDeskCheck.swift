// 只读检查兼容性前提。RustDesk 安装或进程存在都不能证明会话已授权。
import AppKit
import CoreGraphics
import SnugCore
import SnugSystem

@MainActor
enum RustDeskCheck {
    static func run() -> Int32 {
        let bundleID = "com.carriez.rustdesk"
        let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let standardPath = URL(fileURLWithPath: "/Applications/RustDesk.app", isDirectory: true)
        let candidates = [application, standardPath].compactMap { $0 }.compactMap { Bundle(url: $0) }
        let installed = candidates.first { $0.bundleIdentifier == bundleID }
        let version = installed?.infoDictionary?["CFBundleShortVersionString"] as? String
        let accessibility = AX.isTrusted
        let displays = Screens.online()
        print("macOS：\(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("RustDesk：\(version ?? (installed == nil ? "未找到应用" : "版本未知"))")
        print("辅助功能：\(accessibility ? "已授权" : "未授权")")
        print("录屏（伴侣截图）：\(CGPreflightScreenCaptureAccess() ? "已授权" : "未授权")")
        print("在线显示器：\(displays.map { String($0.count) } ?? "无法读取")")
        print("远控会话：未知（当前版本使用菜单栏手动开始与结束）")
        print("输入：原生 RustDesk 输入，事件来源待真机验证")
        return installed != nil && accessibility && displays?.isEmpty == false ? 0 : 1
    }
}
