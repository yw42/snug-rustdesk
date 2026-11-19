// 手势翻译和 CGEvent 之间的读写：接管哪几种事件、事件类型对应 TouchInput 的哪一种、拼要补发的事件、打上记号发出去；
// 补发的事件打上记号：拷贝出来的事件保留来源进程，不打记号会被自己再接管一次。
import CoreGraphics
import Foundation
import SnugCore

enum TouchEvents {
    /// 与原版 Snug 使用不同的记号（'SNRD'）
    private static let marker: Int64 = 0x534E_5244

    /// 只接管左键序列，原生滚轮和右键照常放行
    static let mask = [CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

    static func kind(of type: CGEventType) -> TouchInput.Kind? {
        switch type {
        case .leftMouseDown: .press
        case .leftMouseDragged: .drag
        case .leftMouseUp: .release
        default: nil
        }
    }

    /// Snug 自己补发的事件
    static func isReplay(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    /// 打上记号再发：监听再看到它时原样放行
    static func post(_ event: CGEvent?) {
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cgSessionEventTap)
    }

    /// 右键按下、抬起
    static func rightClick(at point: CGPoint) -> [CGEvent] {
        [CGEventType.rightMouseDown, .rightMouseUp].compactMap { type in
            let click = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .right)
            click?.setIntegerValueField(.mouseEventClickState, value: 1)
            return click
        }
    }

    static func releaseSelection(at point: CGPoint) -> CGEvent? {
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    }

    /// 带相位的像素滚动：App 看到的和触控板两指滑动一样
    static func scroll(_ s: ScrollStep) -> CGEvent? {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                              wheel1: s.pixelsY, wheel2: s.pixelsX, wheel3: 0) else { return nil }
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: s.phase.rawValue)
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: s.momentum.rawValue)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: s.deltaY)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: s.deltaX)
        e.location = s.location
        return e
    }
}
