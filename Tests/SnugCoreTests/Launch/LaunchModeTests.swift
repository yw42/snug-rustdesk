import Foundation
import Testing
@testable import SnugCore

@Suite("启动参数 LaunchMode")
struct LaunchModeTests {
    @Test("没有参数：正常启动")
    func plain() throws {
        #expect(try LaunchMode.parse([]) == .app)
    }

    @Test("系统或 Cocoa 塞进来的单横线参数（-psn_…、-AppleLanguages …）一律忽略")
    func ignoresCocoaArguments() throws {
        #expect(try LaunchMode.parse(["-psn_0_12345"]) == .app)
        #expect(try LaunchMode.parse(["-AppleLanguages", "(zh-Hans)"]) == .app)
    }

    @Test("每种界面都有 --render-<界面> <目录>")
    func renders() throws {
        let out = URL(fileURLWithPath: "/tmp/out")
        for target in RenderTarget.allCases {
            #expect(try LaunchMode.parse(["--render-\(target.rawValue)", "/tmp/out"]) == .render(target, output: out))
        }
    }

    @Test("--set-mode <屏幕编号> <宽> <高>")
    func setMode() throws {
        #expect(try LaunchMode.parse(["--set-mode", "14", "740", "1302"]) == .setMode(display: 14, to: .hiDPI(width: 740, height: 1302)))
    }

    @Test("--restore-mode <屏幕编号> <模式编号> <宽> <高> <像素宽> <像素高> <刷新率> session|permanent：模式编号按无符号写（可以是 0），刷新率可以带小数")
    func restoreMode() throws {
        #expect(try LaunchMode.parse(["--restore-mode", "3", "13", "2560", "1440", "2560", "1440", "59.94", "permanent"])
                == .setMode(display: 3, to: .exact(ScreenMode(ioModeID: 13, width: 2560, height: 1440, pixelWidth: 2560, pixelHeight: 1440, refreshRate: 59.94), permanently: true)))
        #expect(try LaunchMode.parse(["--restore-mode", "3", "0", "540", "1170", "1080", "2340", "60", "session"])
                == .setMode(display: 3, to: .exact(ScreenMode(ioModeID: 0, width: 540, height: 1170, pixelWidth: 1080, pixelHeight: 2340, refreshRate: 60), permanently: false)))
        #expect(throws: LaunchModeError.invalidNumber("--restore-mode", "1.5")) {
            try LaunchMode.parse(["--restore-mode", "3", "1.5", "2560", "1440", "2560", "1440", "60", "session"])
        }
        #expect(throws: LaunchModeError.invalidNumber("--restore-mode", "abc")) {
            try LaunchMode.parse(["--restore-mode", "3", "13", "2560", "1440", "2560", "1440", "abc", "session"])
        }
        #expect(throws: LaunchModeError.invalidNumber("--restore-mode", "forever")) {
            try LaunchMode.parse(["--restore-mode", "3", "13", "2560", "1440", "2560", "1440", "60", "forever"])
        }
        #expect(throws: LaunchModeError.missingValue("--restore-mode")) { try LaunchMode.parse(["--restore-mode", "3", "13", "2560"]) }
    }

    @Test("帮手把模式原样传下去：设回模式的参数由同一个模式拼出来，读回来不走样")
    func restoreModeRoundTrip() throws {
        // 模式编号是 SInt32：系统保留段（0x80000000 起）读出来是负数，命令行上不能出现单横线开头的参数
        for io: Int32 in [7, 0, Int32(bitPattern: 0x8000_1003), .min, -5] {
            let mode = ScreenMode(ioModeID: io, width: 1512, height: 982, pixelWidth: 3024, pixelHeight: 1964, refreshRate: 59.94005994005994)
            for permanently in [true, false] {
                let target = ModeTarget.exact(mode, permanently: permanently)
                #expect(!target.arguments(display: 9).contains { $0.hasPrefix("-") && !$0.hasPrefix("--") })
                guard case .setMode(9, .exact(let parsed, let scope)) = try LaunchMode.parse(target.arguments(display: 9)) else {
                    Issue.record("没解析成设回模式")
                    continue
                }
                #expect(parsed == mode && scope == permanently)
            }
        }
        #expect(try LaunchMode.parse(ModeTarget.hiDPI(width: 540, height: 1170).arguments(display: 9)) == .setMode(display: 9, to: .hiDPI(width: 540, height: 1170)))
    }

    @Test("RustDesk 自检和建屏预览，旧诊断参数拒绝")
    func flags() throws {
        #expect(try LaunchMode.parse(["--rd-check"]) == .checkRustDesk)
        #expect(throws: LaunchModeError.unknownFlag("--check-uu")) { try LaunchMode.parse(["--check-uu"]) }
        #expect(throws: LaunchModeError.unknownFlag("--dump-uu")) { try LaunchMode.parse(["--dump-uu"]) }
        #expect(try LaunchMode.parse(["--preview-screens"]) == .previewScreens)
        #expect(throws: LaunchModeError.self) { try LaunchMode.parse(["--preview-phone"]) }
    }


    @Test("缺参数值、数字写错、两个模式一起：报错而不是悄悄按正常模式启动")
    func errors() {
        #expect(throws: LaunchModeError.missingValue("--render-settings")) { try LaunchMode.parse(["--render-settings"]) }
        #expect(throws: LaunchModeError.missingValue("--set-mode")) { try LaunchMode.parse(["--set-mode", "14"]) }
        #expect(throws: LaunchModeError.missingValue("--set-mode")) { try LaunchMode.parse(["--set-mode", "14", "540"]) }
        #expect(throws: LaunchModeError.invalidNumber("--set-mode", "abc")) { try LaunchMode.parse(["--set-mode", "abc", "540", "950"]) }
        #expect(throws: LaunchModeError.invalidNumber("--set-mode", "0")) { try LaunchMode.parse(["--set-mode", "14", "0", "950"]) }
        #expect(throws: LaunchModeError.conflicting("--preview-screens", "--render-about")) {
            try LaunchMode.parse(["--preview-screens", "--render-about", "/tmp/out"])
        }
    }

    @Test("--probe-screens：一份规格一块实验屏；没写的用实验身份和按最大一档算的像素上限")
    func probeScreensDefaults() throws {
        #expect(try LaunchMode.parse(["--probe-screens", "modes=1180x820"]) == .probeScreens([
            ProbeScreen(name: "Snug 实验屏", serial: 999_000_001, modes: [.init(1180, 820)], maxPixels: .init(2360, 1640), pattern: true),
        ]))
        // 像素上限取各档 2 倍后的最大宽、最大高；第二块起按序号排实验身份和名字
        #expect(try LaunchMode.parse(["--probe-screens", "modes=540x950", "modes=1180x820+800x1200"]) == .probeScreens([
            ProbeScreen(name: "Snug 实验屏", serial: 999_000_001, modes: [.init(540, 950)], maxPixels: .init(1080, 1900), pattern: true),
            ProbeScreen(name: "Snug 实验屏 2", serial: 999_000_002, modes: [.init(1180, 820), .init(800, 1200)],
                        maxPixels: .init(2360, 2400), pattern: true),
        ]))
    }

    @Test("--probe-screens：名字、身份、像素上限、校准图都能指定")
    func probeScreensExplicit() throws {
        let parsed = try LaunchMode.parse(["--probe-screens", "name=Snug 横屏,serial=999000005,modes=1150x803,cap=4320x2160,pattern=off"])
        #expect(parsed == .probeScreens([
            ProbeScreen(name: "Snug 横屏", serial: 999_000_005, modes: [.init(1150, 803)], maxPixels: .init(4320, 2160), pattern: false),
        ]))
    }

    @Test("--probe-screens：main=on 把这块设成主屏（V11），最多一块")
    func probeScreensMain() throws {
        #expect(try LaunchMode.parse(["--probe-screens", "modes=540x950", "modes=1470x956,main=on"]) == .probeScreens([
            ProbeScreen(name: "Snug 实验屏", serial: 999_000_001, modes: [.init(540, 950)], maxPixels: .init(1080, 1900), pattern: true),
            ProbeScreen(name: "Snug 实验屏 2", serial: 999_000_002, modes: [.init(1470, 956)], maxPixels: .init(2940, 1912),
                        pattern: true, main: true),
        ]))
        #expect(throws: LaunchModeError.invalidProbeScreen("modes=1470x956,main=on")) {
            try LaunchMode.parse(["--probe-screens", "modes=540x950,main=on", "modes=1470x956,main=on"])
        }
        #expect(throws: LaunchModeError.invalidProbeScreen("modes=540x950,main=yes")) {
            try LaunchMode.parse(["--probe-screens", "modes=540x950,main=yes"])
        }
    }

    @Test("--probe-screens 写错了：报错，指出是哪一份规格")
    func probeScreensErrors() {
        #expect(throws: LaunchModeError.missingValue("--probe-screens")) { try LaunchMode.parse(["--probe-screens"]) }
        for bad in ["name=x", "modes=", "modes=1180*820", "modes=0x820", "modes=1180x820,size=1", "modes=1180x820,serial=abc",
                    "modes=1180x820,cap=100x100", "modes=1180x820,pattern=maybe", "modes=1180x820,modes=540x950"] {
            #expect(throws: LaunchModeError.invalidProbeScreen(bad)) { try LaunchMode.parse(["--probe-screens", bad]) }
        }
        #expect(throws: LaunchModeError.invalidProbeScreen("serial=999000001,modes=540x950")) {
            try LaunchMode.parse(["--probe-screens", "modes=1180x820", "serial=999000001,modes=540x950"])
        }
    }

    @Test("已删掉的旧参数和未知的双横线参数：报错")
    func removedFlags() {
        for flag in ["--watchdog", "--simulate", "--stress", "--render-tour", "--render-permissions", "--tour"] {
            #expect(throws: LaunchModeError.unknownFlag(flag)) { try LaunchMode.parse([flag, "x"]) }
        }
    }
}
