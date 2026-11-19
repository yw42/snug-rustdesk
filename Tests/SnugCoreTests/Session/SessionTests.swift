import Foundation
import Testing
@testable import SnugCore

@Suite("远程会话")
struct RemoteSessionTests {
    @Test("自动观测区分空闲、中断、重连和会话结束")
    func reconnect() {
        var session = RemoteSession()
        #expect(session.update(.idle, now: at(0)) == [])
        #expect(session.update(.active, now: at(1)) == [.began])
        #expect(session.update(.active, now: at(2)) == [])
        #expect(session.update(.idle, now: at(3)) == [.interrupted])
        #expect(session.inEpisode)
        #expect(session.update(.active, now: at(18)) == [.resumed])
        #expect(session.update(.idle, now: at(20)) == [.interrupted])
        #expect(session.update(.idle, now: at(35)) == [])
        #expect(session.update(.idle, now: at(36)) == [.ended])
        #expect(!session.inEpisode)
    }

    @Test("过期样本被丢弃，未知状态暂停输入并保留会话")
    func unknown() {
        var session = RemoteSession()
        #expect(session.update(.active, now: at(1)) == [.began])
        #expect(session.update(.idle, now: at(0)) == [])
        #expect(session.isConnected)
        #expect(session.update(.idle, now: at(2)) == [.interrupted])
        #expect(session.update(.unknown, now: at(100)) == [])
        #expect(!session.isConnected)
        #expect(session.inEpisode)
        #expect(session.update(.idle, now: at(101)) == [.ended])
    }

    @Test("手动结束还原一次，延迟到来的观测不会重开会话")
    func manual() {
        var session = RemoteSession()
        #expect(session.startManually(at: at(0)) == .began)
        #expect(session.startManually(at: at(1)) == nil)
        #expect(session.update(.idle, now: at(2)) == [])
        #expect(session.endManually() == .ended)
        #expect(session.endManually() == nil)
        #expect(session.update(.active, now: at(3)) == [])
        #expect(!session.inEpisode)
        #expect(session.startManually(at: at(4)) == .began)
    }
}
