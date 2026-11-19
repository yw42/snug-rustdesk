// Snug：用手机通过 RustDesk 用 Mac 时，窗口铺满手机、字够大、手势顺手。
// 这里只负责按启动模式组装；各模式见 LaunchMode（SnugCore）
import AppKit
import SnugCore
import SnugSystem

let mode: LaunchMode
do {
    mode = try LaunchMode.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("\(error)\n\n\(LaunchMode.usage)\n".utf8))
    exit(2)
}

switch mode {
case .render(let target, let output):
    // 只渲染 PNG：不建 AppController、不起感知器、不碰屏幕和窗口
    exit(MainActor.assumeIsolated { Renderer.run(target, output: output) } ? 0 : 1)
case .probeScreens(let screens):
    // 实测用：不建 AppController、不起感知器，只管实验屏。虚拟屏要在跑着的 GUI 进程里才上线
    let app = NSApplication.shared
    let probe = MainActor.assumeIsolated { ScreenProbe(screens: screens) }
    app.delegate = probe
    app.setActivationPolicy(.accessory)
    app.run()
case .setMode(let display, let target):
    Log.setSink(FileLogSink(url: SnugPaths.standard.logFile, processTag: "帮手"))
    let outcome = DisplayMode.apply(target, to: display)
    Log.info("切屏幕 #\(display) 到 \(target)：\(outcome)")
    Log.flush()
    exit(outcome == .switched ? 0 : 1)
case .checkRustDesk:
    exit(MainActor.assumeIsolated { RustDeskCheck.run() })
case .app, .previewScreens:
    let paths = SnugPaths.standard
    Log.setSink(FileLogSink(url: paths.logFile))
    let app = NSApplication.shared
    let delegate = MainActor.assumeIsolated { AppDelegate(paths: paths, preview: mode == .previewScreens) }
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
