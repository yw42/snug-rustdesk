// App 资源库的搜索：点首页的搜索框进入，空着时按字母分组列出全部 App（同 iOS 的 App 资源库），
// 输入后搜 App 名（中文、英文、拼音、首字母）和窗口标题（见 AppList.search）。取消、或从结果里打开了东西就退出
import AppKit
import SnugCore
import SwiftUI

struct SearchPage: View {
    let catalog: AppCatalog
    @Bindable var search: TouchPages
    let panel: PanelState
    let intents: any TouchIntents
    @FocusState private var focused: Bool

    private var query: String { search.trimmedQuery }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: TouchTokens.Space.m) {
                SearchBar {
                    TextField("搜索 App", text: $search.query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                    ClearButton(text: $search.query)
                }
                BarButton(title: "取消") { search.close() }
            }
            .padding(.horizontal, TouchTokens.Space.margin)
            .padding(.top, TouchTokens.Space.m)
            .padding(.bottom, TouchTokens.Space.l)
            ScrollView {
                results.padding(.horizontal, TouchTokens.Space.margin).padding(.bottom, TouchTokens.Space.xxl)
            }
            .scrollIndicators(.never)
        }
        // 面板在进入搜索时才成为键盘焦点，等它一拍再聚焦输入框
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            focused = true
        }
    }

    @ViewBuilder private var results: some View {
        if query.isEmpty {
            LazyVStack(alignment: .leading, spacing: TouchTokens.Space.s) {
                ForEach(AppList.grouped(catalog.installed)) { group in
                    Text(group.letter)
                        .font(TouchTokens.Font.label.font.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, TouchTokens.Space.xs)
                        .padding(.top, TouchTokens.Space.s)
                    ListCard(group.apps.map(\.app)) { appRow($0) }
                }
            }
        } else {
            let result = AppList.search(query, installed: catalog.installed, running: catalog.running)
            if result.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: "无结果", text: "没有与「\(query)」相符的 App 或窗口")
            } else {
                VStack(alignment: .leading, spacing: TouchTokens.Space.xxl) {
                    if !result.apps.isEmpty {
                        TitledSection("App") { ListCard(result.apps) { appRow($0) } }
                    }
                    if !result.windows.isEmpty {
                        TitledSection("窗口") { ListCard(result.windows) { windowRow($0) } }
                    }
                }
            }
        }
    }

    private func appRow(_ app: AppInfo) -> some View {
        let running = catalog.running(app)
        let quitting = running.map { panel.quitting.contains($0.pid) } ?? false
        let subtitle = quitting ? "正在退出" : running?.windowSummary ?? "未打开"
        return ResultRow(icon: catalog.icon(for: app), title: app.name, subtitle: subtitle) {
            search.close()
            intents.open(app)
        }
        .disabled(quitting)
    }

    private func windowRow(_ window: WindowInfo) -> some View {
        ResultRow(icon: catalog.icon(for: window), title: window.displayTitle, subtitle: window.app) {
            search.close()
            intents.pull(window)
        }
        .disabled(panel.quitting.contains(window.key.pid) || panel.closing.contains(window.key))
    }
}

private struct ResultRow: View {
    let icon: NSImage
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppRowLabel(icon: icon, title: title, subtitle: subtitle).padding(TouchTokens.Space.l)
        }
        .buttonStyle(PressableStyle())
    }
}
