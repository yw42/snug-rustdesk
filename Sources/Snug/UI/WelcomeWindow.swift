// 欢迎页：第一次打开时出现，系统引导页的样子：顶部 App 图标，三项讲清 Snug 怎么用，底部「稍后 / 授权…」。
// 授权由 PermissionFlow 打开系统设置，旁边浮出一个小窗口，把 Snug 拖进列表即可。之后缺权限时从设置里也能再打开。
// 授权状态读 AppState（AppController 每拍刷新），这里不自己轮询
import AppKit
import SwiftUI
import SnugCore

struct WelcomeView: View {
    let state: AppState
    let onDone: () -> Void

    var body: some View {
        let granted = state.accessibilityTrusted
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                Text("欢迎使用 Snug").font(.largeTitle.bold())
                Text("远程 Mac 的显示与触控增强").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 20) {
                Feature(symbol: "rectangle.on.rectangle", title: "选择 Snug 的屏", detail: "RustDesk 屏幕列表中切换；不切换则一切如常")
                Feature(symbol: "hand.point.up.left.fill", title: "点选 App 或窗口", detail: "铺满这块屏，手机和平板上字号自动放大")
                Feature(symbol: "hand.draw.fill", title: "触控手势", detail: "单指滚动 · 长按选择 · 长按松开右键")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                SettingLabel.accessibility
                Spacer(minLength: 12)
                PermissionStatus(granted: granted)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 12) {
                Spacer()
                if granted {
                    Button("完成", action: onDone).keyboardShortcut(.defaultAction)
                } else {
                    Button("稍后", action: onDone)
                    AuthorizeButton(pane: .accessibility)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520)
    }
}

/// 一项功能：图标统一大小，标题 + 一行说明
private struct Feature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
final class WelcomeWindowController {
    private let state: AppState
    private var window: NSWindow?
    private var onDone: (() -> Void)?
    private var closeObserver: (any NSObjectProtocol)?

    init(state: AppState) { self.state = state }

    func show(onDone: (() -> Void)? = nil) {
        if let onDone { self.onDone = onDone }
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(state: state) { [weak self] in
                self?.window?.close()
            }))
            w.styleMask = [.titled, .closable]
            w.title = "Snug"
            w.isReleasedWhenClosed = false
            w.center()
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w,
                                                                   queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish() }
            }
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        window = nil
        let done = onDone
        onDone = nil
        done?()
    }
}
