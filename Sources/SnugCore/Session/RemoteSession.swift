import Foundation

public enum RemoteActivity: Equatable, Sendable {
    case idle, active, unknown
}

public struct RemoteSession: Sendable {
    private var episode = SessionEpisode()
    private var lastObservation: Date?
    public private(set) var activity = RemoteActivity.unknown
    public private(set) var manual = false

    public init() {}

    public var isConnected: Bool { activity == .active }
    public var inEpisode: Bool { episode.isActive }

    public mutating func update(_ sample: RemoteActivity, now: Date) -> [EpisodeChange] {
        guard !manual, lastObservation.map({ now > $0 }) ?? true else { return [] }
        lastObservation = now
        let previous = activity
        activity = sample
        switch sample {
        case .unknown:
            return []
        case .idle:
            if let ended = episode.advance(to: now) { return [ended] }
            return episode.disconnected(at: now).map { [$0] } ?? []
        case .active:
            guard previous != .active else { return [] }
            let ended = episode.advance(to: now)
            let started = episode.connected(at: now)
            return ended.map { [$0, started] } ?? [started]
        }
    }

    public mutating func startManually(at now: Date) -> EpisodeChange? {
        guard !inEpisode else { return nil }
        manual = true
        activity = .active
        return episode.connected(at: now)
    }

    public mutating func endManually() -> EpisodeChange? {
        manual = true
        activity = .idle
        return episode.endNow()
    }
}
