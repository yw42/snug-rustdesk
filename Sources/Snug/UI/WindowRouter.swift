// 各窗口的开关。窗口都读同一份 AppState，意图交给 AppController
import AppKit
import SnugCore

@MainActor
final class WindowRouter: Navigation {
    private let controller: AppController
    private lazy var settings = SettingsWindowController(state: controller.state, intents: controller, navigation: self)
    private lazy var about = AboutWindowController()
    private lazy var library = LibraryWindowController(state: controller.state, catalog: controller.catalog) { [controller] in
        ScreenIntents(id: $0, app: controller)
    }
    private lazy var welcome = WelcomeWindowController(state: controller.state)
    private lazy var update = UpdateWindowController(state: controller.state, intents: controller)

    init(controller: AppController) { self.controller = controller }

    func openSettings(on display: DisplayID? = nil) { settings.show(on: display) }

    func openWelcome() { welcome.show() }
    func openAbout(on display: DisplayID? = nil) { about.show(on: display) }
    func openLibrary(on display: DisplayID?) { library.show(on: display) }
    func openUpdate() { showUpdate(activating: true) }

    /// 查到新版本：能自动更新的弹更新窗口（讲落下了哪几版）；只能手动下载的没有更新日志可看，打开设置的「通用」页（更新在那里）
    func showUpdate(activating: Bool) {
        if controller.state.update.available != nil {
            update.show(activating: activating)
        } else {
            settings.show(.general, activating: activating)
        }
    }

    /// 第一次打开：欢迎页关掉后记下「看过了」
    func showFirstWelcome() {
        welcome.show { [weak self] in self?.controller.markWelcomed() }
    }

}
