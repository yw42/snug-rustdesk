import Foundation
import Testing
@testable import SnugCore

@Suite("更新源 UpdateSource")
struct UpdateSourceTests {
    private let version = Version(major: 2, minor: 1, patch: 0)

    @Test("GitHub：最新 Release 的 update.json，各版本 Release 下的包")
    func github() {
        let source = UpdateSource.github
        #expect(source.feedURL.absoluteString == "https://github.com/yw42/snug-rustdesk/releases/latest/download/update.json")
        #expect(source.url(of: "SnugRustDesk-2.1.0.pack", in: version).absoluteString
            == "https://github.com/yw42/snug-rustdesk/releases/download/v2.1.0/SnugRustDesk-2.1.0.pack")
        #expect(source.downloadPage.absoluteString == "https://github.com/yw42/snug-rustdesk/releases/latest")
    }
}
