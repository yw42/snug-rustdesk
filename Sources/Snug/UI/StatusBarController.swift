// 菜单栏：顶上一行说清此刻的状态（远程中 · 设备 · 正在看哪块屏）；「App 资源库」给电脑屏用，在哪块屏的菜单栏点就在哪块屏打开；
// 设置、关于（同样摆到点的那块屏）、退出。手机、平板屏上的操作都在屏上的面板里。每次展开都按 AppState 现做，和设置窗口永远一致
import AppKit
import Observation
import SnugCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state: AppState
    private let intents: any AppIntents
    private let navigation: any Navigation

    init(state: AppState, intents: any AppIntents, navigation: any Navigation) {
        self.state = state
        self.intents = intents
        self.navigation = navigation
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.image = Self.icon
        refreshButton()
    }

    /// 菜单栏图标：SF Symbols，同原型（系统图标本身就是模板图，深色菜单栏自动反白）
    private static let icon: NSImage? = NSImage(systemSymbolName: "iphone.radiowaves.left.and.right", accessibilityDescription: "Snug")?
        .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))

    /// 屏都关着、没有权限时图标变灰；提示文字随状态变
    private func refreshButton() {
        withObservationTracking {
            item.button?.appearsDisabled = !state.config.screens.contains(where: \.enabled) || !state.accessibilityTrusted
            item.button?.toolTip = "Snug RustDesk：\(StatusText(state).headline)"
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.refreshButton() } }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(status())
        if !state.quitting {
            if state.connection == .idle, state.accessibilityTrusted, state.config.screens.contains(where: { $0.enabled }),
               state.previewing || state.desks.desks.isEmpty {
                menu.addItem(action("手动开始伴侣会话", #selector(startManualSession), symbol: "play.circle"))
            } else if state.connection != .idle {
                menu.addItem(action("结束伴侣会话并还原", #selector(endSessionNow), symbol: "xmark.circle"))
            }
        }
        // 虚拟屏成为主屏、本机看不到时，菜单栏是回到 Mac 前最好找的出口
        if state.config.mainScreen != nil { menu.addItem(action("取消设为主屏", #selector(cancelMain), symbol: "menubar.rectangle")) }
        menu.addItem(.separator())
        let library = action("App 资源库", #selector(openLibrary), symbol: "square.grid.2x2")
        // 电脑屏都不在时没有地方放
        library.isEnabled = !state.libraryScreens.isEmpty
        menu.addItem(library)
        menu.addItem(.separator())
        let settings = action("设置…", #selector(openSettings), key: ",", symbol: "gearshape")
        // 有新版本：系统的菜单角标，更新在设置的通用页里
        if state.update.hasNewVersion { settings.badge = NSMenuItemBadge(string: "新版本") }
        menu.addItem(settings)
        menu.addItem(action("关于 Snug RustDesk", #selector(openAbout), symbol: "info.circle"))
        menu.addItem(.separator())
        menu.addItem(action("退出 Snug RustDesk", #selector(quit), key: "q", symbol: "power"))
    }

    /// 最上面一行：状态图标块 + 此刻的状态和一行说明。只看不点，所以用自定义视图（不会高亮）
    private func status() -> NSMenuItem {
        let view = NSHostingView(rootView: MenuStatusView(text: StatusText(state), status: state.status))
        view.frame.size = view.fittingSize
        view.autoresizingMask = [.width]
        let it = NSMenuItem()
        it.view = view
        return it
    }

    private func action(_ title: String, _ sel: Selector, key: String = "", symbol: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        it.target = self
        it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return it
    }

    @objc private func startManualSession() { intents.startManualSession() }
    @objc private func cancelMain() { intents.setMainScreen(nil) }
    @objc private func endSessionNow() { intents.endSessionNow() }
    @objc private func openSettings() { navigation.openSettings(on: clickedScreen?.displayID) }
    @objc private func openAbout() { navigation.openAbout(on: clickedScreen?.displayID) }
    /// 在哪块屏的菜单栏点，就在哪块屏打开
    @objc private func openLibrary() {
        let screen = clickedScreen
        let display = screen?.displayID
        // 认不出是哪块屏的菜单栏时，资源库按可用电脑屏选，开错屏时从这里查
        Log.info("菜单栏：点了「App 资源库」，在\(screen.map { "「\($0.localizedName)」（display \(display.map { "\($0)" } ?? "?")）" } ?? "认不出的屏")的菜单栏")
        navigation.openLibrary(on: display)
    }
    @objc private func quit() { intents.quit() }

    /// 点的是哪块屏的菜单栏：菜单栏图标跟着活动的那块屏走
    private var clickedScreen: NSScreen? { item.button?.window?.screen }
}

struct MenuStatusView: View {
    let text: StatusText
    let status: StatusToken

    var body: some View {
        HStack(spacing: MacTokens.Space.s) {
            Image(systemName: status.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: MacTokens.Size.iconTile, height: MacTokens.Size.iconTile)
                .background(status.color.gradient, in: RoundedRectangle(cornerRadius: MacTokens.Radius.iconTile, style: .continuous))
            VStack(alignment: .leading, spacing: MacTokens.Space.xxs) {
                Text(text.headline).font(.system(size: MacTokens.Font.body.size, weight: .medium))
                if let detail = text.detail { Text(detail).font(.system(size: MacTokens.Font.callout.size)).foregroundStyle(.secondary) }
            }
        }
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, MacTokens.Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
