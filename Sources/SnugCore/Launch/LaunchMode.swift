// 启动参数一次解析成启动模式，main.swift 只按模式组装。
// 只认双横线参数；单横线的（-psn_…、-AppleLanguages …）是系统或 Cocoa 塞进来的，忽略。
// 未知的双横线参数直接报错：拼错一个参数时宁可不启动，也不要悄悄按正常模式开始监控
import Foundation

public enum RenderTarget: String, CaseIterable, Equatable, Sendable {
    /// 设置窗口三页，加添加屏幕、屏幕详情
    case settings
    case welcome, about
    /// 查到新版本时的更新窗口（几种状态）
    case update
    /// 菜单栏菜单
    case menu
    /// 手机、平板屏上的 App 资源库（竖屏、横屏、平板，几种状态）
    case screens
    /// 电脑屏的 App 资源库窗口
    case library
}

public enum LaunchMode: Equatable, Sendable {
    case app
    case checkRustDesk
    /// 正常启动，但不等远程，直接建出开着的屏（开发自测用：没有手机也能看屏和上面的列表）
    case previewScreens
    /// 只把界面渲染成 PNG
    case render(RenderTarget, output: URL)
    /// 帮手模式：把一块屏切到 target 后立即退出（Snug 的屏换档，或把加屏、撤屏时被 macOS 拨动的屏设回去）。
    /// 目标由主程序算好传来，帮手不读配置。主程序亲自切模式，Snug 的屏释放时会拖 40 秒以上才下线；交给短命的子进程切就没有这个问题
    case setMode(display: DisplayID, to: ModeTarget)
    /// 实测：按规格建几块实验屏，打印它们的模式，按 Ctrl-C 撤掉（见 ProbeScreen）
    case probeScreens([ProbeScreen])

    public static let usage = """
    用法：Snug [模式]
      （无参数）                      正常启动
      --rd-check                      只读检查 RustDesk、权限和显示器
      --preview-screens               正常启动，不等远程就建出开着的屏（开发自测用）
      --render-<界面> <目录>           把界面渲染成 PNG（界面：\(RenderTarget.allCases.map(\.rawValue).joined(separator: " / "))）
      --probe-screens <规格> [<规格> …]  实测用：建实验屏、打印模式，按 Ctrl-C 撤掉。规格写成
                                      modes=1180x820+1000x695[,name=名字][,serial=999000001][,cap=像素宽x像素高][,pattern=off][,main=on]
      --set-mode <屏幕编号> <宽> <高>   把 Snug 的屏换到这一档（点，2 倍）（主程序内部用）
      --restore-mode <屏幕编号> <模式编号> <宽> <高> <像素宽> <像素高> <刷新率> session|permanent
                                      把一块屏设回这个模式，只对本次登录或连永久配置（主程序内部用）
    """

    public static func parse(_ arguments: [String]) throws -> LaunchMode {
        var rest = arguments.filter { $0.hasPrefix("--") || !$0.hasPrefix("-") }[...]
        var mode: (flag: String, value: LaunchMode)?
        while let flag = rest.popFirst() {
            guard flag.hasPrefix("--") else { continue }
            let value = try parseMode(flag, &rest)
            if let first = mode { throw LaunchModeError.conflicting(first.flag, flag) }
            mode = (flag, value)
        }
        return mode?.value ?? .app
    }

    private static func parseMode(_ flag: String, _ rest: inout ArraySlice<String>) throws -> LaunchMode {
        func value() throws -> String {
            guard let v = rest.first, !v.hasPrefix("--") else { throw LaunchModeError.missingValue(flag) }
            rest.removeFirst()
            return v
        }
        func number<N: FixedWidthInteger>(_: N.Type, orZero: Bool = false) throws -> N {
            let raw = try value()
            guard let n = N(raw), n > 0 || (orZero && n == 0) else { throw LaunchModeError.invalidNumber(flag, raw) }
            return n
        }
        func rate() throws -> Double {
            let raw = try value()
            guard let r = Double(raw), r.isFinite, r >= 0 else { throw LaunchModeError.invalidNumber(flag, raw) }
            return r
        }
        if flag.hasPrefix("--render-"), let target = RenderTarget(rawValue: String(flag.dropFirst("--render-".count))) {
            return .render(target, output: URL(fileURLWithPath: try value()))
        }
        switch flag {
        case "--rd-check":
            return .checkRustDesk
        case "--preview-screens":
            return .previewScreens
        case "--probe-screens":
            var specs: [String] = []
            while let spec = rest.first, !spec.hasPrefix("--") {
                specs.append(spec)
                rest.removeFirst()
            }
            guard !specs.isEmpty else { throw LaunchModeError.missingValue(flag) }
            return .probeScreens(try ProbeScreen.parse(specs))
        case "--set-mode":
            return .setMode(display: try number(DisplayID.self), to: .hiDPI(width: try number(Int.self), height: try number(Int.self)))
        case "--restore-mode":
            let display = try number(DisplayID.self)
            let mode = ScreenMode(ioModeID: Int32(bitPattern: try number(UInt32.self, orZero: true)), width: try number(Int.self), height: try number(Int.self),
                                  pixelWidth: try number(Int.self), pixelHeight: try number(Int.self), refreshRate: try rate())
            let scope = try value()
            guard [ModeTarget.permanent, ModeTarget.session].contains(scope) else { throw LaunchModeError.invalidNumber(flag, scope) }
            return .setMode(display: display, to: .exact(mode, permanently: scope == ModeTarget.permanent))
        default:
            throw LaunchModeError.unknownFlag(flag)
        }
    }
}

public enum LaunchModeError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownFlag(String)
    case missingValue(String)
    case invalidNumber(String, String)
    case conflicting(String, String)
    case invalidProbeScreen(String)

    public var description: String {
        switch self {
        case .unknownFlag(let f): "不认识的参数 \(f)"
        case .missingValue(let f): "\(f) 缺少参数值"
        case .invalidNumber(let f, let v): "\(f) 的参数「\(v)」不是正整数"
        case .conflicting(let a, let b): "\(a) 和 \(b) 不能一起用"
        case .invalidProbeScreen(let spec): "实验屏的规格「\(spec)」写错了（键只认 modes、name、serial、cap、pattern、main，各写一次；"
            + "尺寸写成 宽x高；像素上限要框得住最大一档的 2 倍；身份不能重复；主屏最多一块）"
        }
    }
}
