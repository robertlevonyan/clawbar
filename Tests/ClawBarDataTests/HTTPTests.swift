import Foundation
import Testing
@testable import ClawBarData

/// A server that never goes idle: one byte every 50 ms, forever.
final class TrickleProtocol: URLProtocol, @unchecked Sendable {
    private var timer: DispatchSourceTimer?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "trickle"))
        t.schedule(deadline: .now(), repeating: 0.05)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didLoad: Data([0x20]))
        }
        timer = t
        t.resume()
    }

    override func stopLoading() {
        timer?.cancel()
        timer = nil
    }
}

@Suite struct HTTPTests {
    @Test(.timeLimit(.minutes(1))) func theTimeoutBoundsTheWholeRequestNotJustItsIdleGaps() async {
        let http = URLSessionHTTP(protocolClasses: [TrickleProtocol.self])
        let start = Date()
        await #expect(throws: (any Error).self) {
            _ = try await http.get(URL(string: "https://slow.example/feed")!, timeout: 0.5)
        }
        #expect(Date().timeIntervalSince(start) < 3)
    }

    @Test func everyRequestCarriesClawBarsUserAgent() {
        let r = URLSessionHTTP.request(URL(string: "https://api.example/x")!, timeout: 15)
        #expect(r.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("ClawBar/") == true)
        #expect(r.timeoutInterval == 15)
    }
}
