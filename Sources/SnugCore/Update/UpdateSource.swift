// 派生版的更新包和发布说明只从自己的 GitHub Releases 读取。
import Foundation

public enum UpdateSource: String, Codable, Sendable {
    case github

    public var title: String { "GitHub" }

    private static let githubBase = URL(string: "https://github.com/yw42/snug-rustdesk/releases")!

    public var feedURL: URL {
        Self.githubBase.appendingPathComponent("latest/download/update.json")
    }

    public func url(of file: String, in version: Version) -> URL {
        Self.githubBase.appendingPathComponent("download/v\(version)").appendingPathComponent(file)
    }

    public var downloadPage: URL {
        Self.githubBase.appendingPathComponent("latest")
    }
}
