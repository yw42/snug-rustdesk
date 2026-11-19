// 手机、平板屏上界面共用的样式。数值一律直接取设计令牌 TouchTokens（design/design-tokens.json 的 touch），和 Mac 上直接用 MacTokens 一样，
// 不另起别名：手机竖屏 1 点在手机上约 0.82 点，所以字和按钮都按 iOS 的大小放大一档，看起来才和手机上的原生 App 一样大；
// 平板上照样用这些数（V10：约大 1.24 倍，字大、舒服）。颜色用 iOS 的分组背景色（macOS 没有对应的系统色）
import AppKit
import SnugCore
import SwiftUI

extension TouchTokens.Color {
    /// 面板窗口的底色（NSPanel 要 NSColor）
    static var backgroundNSColor: NSColor { NSColor(background) }
}

extension DeviceKind {
    /// 横屏两栏时左边 App 列表的宽度（电脑屏没有面板，跟手机走）
    var landscapeSidebar: CGFloat {
        switch self {
        case .tablet: TouchTokens.Layout.TabletLandscape.sidebar
        case .phone, .computer: TouchTokens.Layout.PhoneLandscape.sidebar
        }
    }
}

/// 按下时轻微变暗，松手恢复（手机上点下去要有反馈）；正在忙、点不了时变淡，看得出来点不了
struct PressableStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? MotionTokens.pressedOpacity : 1) : MotionTokens.disabledOpacity)
            .contentShape(Rectangle())
    }
}
