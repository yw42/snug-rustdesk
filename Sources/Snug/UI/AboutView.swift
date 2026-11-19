// 「关于 Snug」：独立的小窗口，只放名称、版本、链接、致谢与免责声明（软件更新在设置的通用页）
import AppKit
import SwiftUI
import SnugCore

struct AboutView: View {
    private struct Credit: Identifiable {
        let name, url, author, usage: String
        var id: String { name }
    }

    private let credits = [
        Credit(name: "Snug", url: "https://github.com/zephyr4123/snug",
               author: "zephyr4123", usage: "本项目衍生来源"),
        Credit(name: "UUyc-companion", url: "https://github.com/aoyamashou/UUyc-companion",
               author: "AoyamaShou", usage: "项目前身"),
        Credit(name: "PermissionFlow", url: "https://github.com/jaywcjlove/PermissionFlow",
               author: "小弟调调（jaywcjlove）", usage: "授权引导"),
        Credit(name: "Better Remote", url: "https://github.com/pincc-debug/better-remote",
               author: "pincc-debug", usage: "单指滚动思路"),
        Credit(name: "FreeDisplay", url: "https://github.com/huberdf/FreeDisplay",
               author: "huberdf", usage: "虚拟屏接口声明"),
    ]

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Snug RustDesk").font(.title2.bold())
                            Text(Updater.current?.description ?? "开发版").foregroundStyle(.secondary).monospacedDigit()
                        }
                        Text("远程 Mac 的显示与触控增强")
                        Link("github.com/yw42/snug-rustdesk", destination: URL(string: "https://github.com/yw42/snug-rustdesk")!)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                ForEach(credits) { c in
                    LabeledContent {
                        Text(c.usage).foregroundStyle(.secondary)
                    } label: {
                        HStack(spacing: 4) {
                            Link(c.name, destination: URL(string: c.url)!)
                            Text("· \(c.author)").foregroundStyle(.secondary)
                        }
                    }
                }
                Text("社区 PR 作者：bubble、gencheng liu、Rongzheng Liu").foregroundStyle(.secondary)
            } header: {
                Text("致谢（MIT 许可）")
            }
        }
        .formStyle(.grouped)
        .frame(width: MacTokens.Size.aboutWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    /// display：从哪块屏的菜单栏打开的（见 NSWindow.bring）
    func show(on display: DisplayID? = nil, activating: Bool = true) {
        if window == nil {
            // 先定尺寸再居中（NSWindow(hosting:)），否则按 0×0 居中，窗口偏到右下
            let w = NSWindow(hosting: AboutView(), title: "关于 Snug RustDesk")
            w.titlebarAppearsTransparent = true
            window = w
        }
        window?.bring(to: display)
        window?.present(activating: activating)
    }
}
