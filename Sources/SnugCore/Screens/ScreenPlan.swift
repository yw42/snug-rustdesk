// 配置和会话决定期望屏幕。临时主屏随会话一起结束。
import Foundation

public enum ScreenPlan {
    /// 辅助功能允许后，只在会话或预览期间建屏。
    public static func wishes(config: AppConfig, remote: Bool, trusted: Bool, preview: Bool = false) -> [ScreenWish] {
        guard trusted, remote || preview else { return [] }
        let shown = config.screens.filter(\.enabled).prefix(ScreenConfig.limit)
        return shown.map { screen in
            ScreenWish(id: screen.id, spec: spec(of: screen), fit: fit(of: screen), behavior: behavior(screen.device.kind),
                       main: remote && config.mainScreen == screen.id)
        }
    }

    /// 配置里的一项 → 屏的身份：竖横各一个产品号，像素上限和方向一致（V4、V5）
    public static func spec(of screen: ScreenConfig) -> ScreenSpec {
        let portrait = screen.orientation == .portrait
        return ScreenSpec(name: screen.name, productID: portrait ? ScreenSpec.portraitProductID : ScreenSpec.landscapeProductID,
                          serials: screen.serials, maxPixels: portrait ? ScreenFit.portraitPixels : ScreenFit.landscapePixels)
    }

    /// 配置里的一项 → 比例和档位
    public static func fit(of screen: ScreenConfig) -> ScreenFit { fit(screen.device, screen.orientation) }

    /// 这台设备、这个方向的比例和档位（换型号时先算出来记日志）
    public static func fit(_ device: DeviceChoice, _ orientation: Orientation) -> ScreenFit {
        ScreenFit(device: device.screen, kind: device.kind, orientation: orientation)
    }

    /// 类别 → 行为（哪些类别算触屏见 DeviceKind.isTouch）
    public static func behavior(_ kind: DeviceKind) -> ScreenBehavior {
        kind.isTouch ? .touchScreen : .computer
    }
}
