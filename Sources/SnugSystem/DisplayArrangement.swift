// 屏幕排布：各屏的原点、设主屏、按记下的原点摆回去。主屏就是原点在 (0, 0) 的那块屏，
// 设主屏 = 把它挪到 (0, 0)、别的屏跟着平移，相对位置不变。只对本次登录生效。
// 会卡住：不在主线程上调（原作者实测），放到后台线程做完再回来
import ColorSync
import CoreGraphics
import Foundation
import SnugCore

@MainActor
public final class DisplayArrangementService: DisplayArrangement {
    private let recovery: JSONFile<[String: CGPoint]>?

    public init(recoveryURL: URL? = nil) {
        recovery = recoveryURL.map { JSONFile(url: $0) }
    }

    public func saveRecoveryOrigins(_ origins: [DisplayID: CGPoint]) -> Bool {
        guard let recovery else { return true }
        switch recovery.load() {
        case .missing:
            break
        case .loaded:
            Log.warn("上次屏幕排布尚待恢复，保留当前主屏")
            return false
        case .corrupt(let error):
            Log.error("读取原排布失败：\(error)")
            return false
        }
        var snapshot: [String: CGPoint] = [:]
        for (display, origin) in origins {
            guard let key = Self.displayKey(display), snapshot[key] == nil else {
                Log.error("无法唯一识别显示器 #\(display)，保留当前主屏")
                return false
            }
            snapshot[key] = origin
        }
        guard snapshot.values.filter({ $0 == .zero }).count == 1 else {
            Log.error("无法唯一识别原主屏")
            return false
        }
        do {
            try recovery.save(snapshot)
            return true
        } catch {
            Log.error("保存原排布失败：\(error)")
            return false
        }
    }

    public func recoverOrigins() async {
        guard let recovery else { return }
        switch recovery.load() {
        case .missing:
            return
        case .corrupt(let error):
            Log.error("读取原排布失败：\(error)")
        case .loaded(let snapshot):
            if await restoreSnapshot(snapshot) { clearRecoveryOrigins() }
        }
    }

    private func restoreSnapshot(_ snapshot: [String: CGPoint]) async -> Bool {
        let online = Self.origins()
        var targets: [DisplayID: CGPoint] = [:]
        var matched = Set<String>()
        for display in online.keys {
            guard let key = Self.displayKey(display), let origin = snapshot[key] else { continue }
            guard matched.insert(key).inserted else {
                Log.warn("显示器身份重复，保留待恢复排布")
                return false
            }
            guard origin.x.isFinite, origin.y.isFinite,
                  abs(origin.x) < CGFloat(Int32.max - 1), abs(origin.y) < CGFloat(Int32.max - 1) else {
                Log.error("保存的显示器坐标无效，保留待恢复排布")
                return false
            }
            targets[display] = origin
        }
        guard targets.values.filter({ $0 == .zero }).count == 1 else {
            Log.warn("原主屏未在线，保留待恢复排布")
            return false
        }
        if targets.allSatisfy({ online[$0.key] == $0.value }) { return true }
        return await restoreOnline(targets)
    }

    public func clearRecoveryOrigins() {
        do { try recovery?.remove() }
        catch { Log.error("删除原排布快照失败：\(error)") }
    }

    private static func displayKey(_ display: DisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    public func origins() -> [DisplayID: CGPoint] { Self.origins() }

    public func makeMain(_ id: DisplayID) async -> Bool {
        let error = await Task.detached {
            let now = Self.origins()
            guard let shift = now[id] else { return CGError.illegalArgument }
            return Self.configure(now.mapValues { CGPoint(x: $0.x - shift.x, y: $0.y - shift.y) })
        }.value
        if error != .success { Log.error("设主屏 #\(id)：CGError=\(error.rawValue)") }
        return error == .success
    }

    public func restore(_ saved: [DisplayID: CGPoint]) async -> Bool {
        guard let recovery else { return await restoreOnline(saved) }
        switch recovery.load() {
        case .loaded(let snapshot):
            return await restoreSnapshot(snapshot)
        case .missing:
            Log.error("原排布快照缺失，无法核对显示器身份")
        case .corrupt(let error):
            Log.error("读取原排布失败：\(error)")
        }
        return false
    }

    private func restoreOnline(_ saved: [DisplayID: CGPoint]) async -> Bool {
        let error = await Task.detached {
            let online = Self.origins()
            let targets = saved.filter { online[$0.key] != nil }
            guard targets.values.contains(.zero) else { return CGError.illegalArgument }
            return Self.configure(targets)
        }.value
        if error != .success { Log.error("摆回排布：CGError=\(error.rawValue)") }
        return error == .success
    }

    /// 每块在线屏此刻的原点（全局坐标，左上原点）
    nonisolated static func origins() -> [DisplayID: CGPoint] {
        Dictionary(uniqueKeysWithValues: (Screens.online() ?? []).map { ($0, CGDisplayBounds($0).origin) })
    }

    private nonisolated static func configure(_ targets: [DisplayID: CGPoint]) -> CGError {
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success else { return begin }
        for (id, origin) in targets {
            let staged = CGConfigureDisplayOrigin(config, id, Int32(origin.x.rounded()), Int32(origin.y.rounded()))
            guard staged == .success else {
                CGCancelDisplayConfiguration(config)
                return staged
            }
        }
        let done = CGCompleteDisplayConfiguration(config, .forSession)
        if done != .success { CGCancelDisplayConfiguration(config) }
        return done
    }
}
