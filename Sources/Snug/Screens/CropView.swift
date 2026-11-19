// 裁剪界面：盖满这块屏。图片等比摆在中间（四周留出边距，手指够得到边角上的把手），
// 默认整张都选着，拖四角或四边往里收；顶部左边取消、右边完成（平板上让开右上角 UU 的按钮）。
// 选区存成图片里的比例（见 CropGeometry），换档时跟着图片走；尺寸按这一档的倍率放大（倍率由界面宽度算）
import SnugCore
import SwiftUI

struct CropView: View {
    let image: NSImage
    let pixelSize: CGSize
    let onCancel: () -> Void
    /// 完成：选区（图片里的比例）
    let onDone: (CGRect) -> Void

    /// 选区，图片里的比例；一开始是整张
    @State private var selection = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// 正在拖的把手，和按下时的选区（界面坐标）
    @State private var dragging: (handle: CropGeometry.Handle, start: CGRect)?

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            let shown = metrics.shown(pixelSize, in: geo.size)
            let current = CropGeometry.rect(selection, in: shown)
            ZStack(alignment: .topLeading) {
                Color.black
                Image(nsImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .position(x: shown.midX, y: shown.midY)
                // 选区外压暗：整块挖掉选区
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(current)
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                handles(current, metrics)
                topBar(metrics) { onDone(selection) }
            }
            .contentShape(Rectangle())
            .gesture(drag(current, shown: shown, metrics: metrics))
        }
    }

    // MARK: 把手

    /// 四角 L 形 + 四边中点短线，和手机上的截图裁剪一样；外加一圈细边框。
    /// 把手画在选区外沿：选区贴着图片边时，白把手也落在黑底上，不会和浅色截图混在一起
    private func handles(_ sel: CGRect, _ metrics: Metrics) -> some View {
        let line = 4 * metrics.scale
        let outer = sel.insetBy(dx: -line / 2, dy: -line / 2)
        let corner = min(metrics.corner, sel.width / 3, sel.height / 3)
        let tick = min(metrics.corner, sel.width / 4) / 2
        let marks = Path { path in
            for (x, dx) in [(outer.minX, corner), (outer.maxX, -corner)] {
                for (y, dy) in [(outer.minY, corner), (outer.maxY, -corner)] {
                    path.move(to: CGPoint(x: x, y: y + dy))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + dx, y: y))
                }
            }
            for y in [outer.minY, outer.maxY] {
                path.move(to: CGPoint(x: outer.midX - tick, y: y))
                path.addLine(to: CGPoint(x: outer.midX + tick, y: y))
            }
            for x in [outer.minX, outer.maxX] {
                path.move(to: CGPoint(x: x, y: outer.midY - tick))
                path.addLine(to: CGPoint(x: x, y: outer.midY + tick))
            }
        }
        return ZStack {
            Path(sel).stroke(.white.opacity(0.8), lineWidth: metrics.scale)
            marks.stroke(.white, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }
    }

    /// 拖把手：按下时看抓住了哪个（都不近就不动，免得误改），之后按手指移动的距离挪那条边或那个角
    private func drag(_ current: CGRect, shown: CGRect, metrics: Metrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging == nil {
                    guard let handle = CropGeometry.handle(at: value.startLocation, of: current, radius: metrics.grabRadius) else { return }
                    dragging = (handle, current)
                }
                guard let dragging else { return }
                let moved = CropGeometry.resized(dragging.start, dragging.handle, by: value.translation, within: shown, minSide: metrics.minSide)
                selection = CropGeometry.unitRect(moved, in: shown)
            }
            .onEnded { _ in dragging = nil }
    }

    // MARK: 按钮

    private func topBar(_ metrics: Metrics, done: @escaping () -> Void) -> some View {
        // 点按区域至少一个手指大（PressableStyle 按 label 的范围接点击）
        let side = TouchTokens.Size.touchTarget * metrics.scale
        return HStack {
            Button(action: onCancel) { Text("取消").frame(minWidth: side, minHeight: side) }
            Spacer()
            Button(action: done) { Text("完成").frame(minWidth: side, minHeight: side) }
        }
        .font(.system(size: TouchTokens.Font.body.size * metrics.scale, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(PressableStyle())
        .padding(.horizontal, metrics.margin)
        // 让开的宽度和别的尺寸一样跟着倍率放大
        .frame(height: metrics.topBar)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
    }

    /// 跟着倍率走的尺寸
    private struct Metrics {
        let scale: CGFloat

        init(size: CGSize) { scale = ScreenFit.scale(screen: size) }

        /// 顶部留给「取消 / 完成」
        var topBar: CGFloat { 64 * scale }
        /// 四周留出抓把手的空间
        var margin: CGFloat { 22 * scale }
        /// 离把手这么近就算抓住了
        var grabRadius: CGFloat { 34 * scale }
        /// 选区最小边长：再小就没法继续拖了
        var minSide: CGFloat { 44 * scale }
        /// 角上 L 形的边长
        var corner: CGFloat { 20 * scale }

        /// 图片的显示范围：顶部让出按钮，四周留边距，等比居中
        func shown(_ image: CGSize, in size: CGSize) -> CGRect {
            let area = CGRect(x: margin, y: topBar, width: max(1, size.width - margin * 2), height: max(1, size.height - topBar - margin))
            return CropGeometry.fittedRect(image: image, in: area)
        }
    }
}

