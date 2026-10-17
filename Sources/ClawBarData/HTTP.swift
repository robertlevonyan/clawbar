import Foundation
import ClawBarShared

/// One GET; tests answer from fixtures instead of the network.
protocol HTTPFetching: Sendable {
    func get(_ url: URL, timeout: TimeInterval) async throws -> Data
}

struct HTTPStatusError: Error, CustomStringConvertible {
    var url: URL
    var status: Int

    var description: String { "HTTP \(status) from \(url.host ?? url.absoluteString)" }
}

/// An ephemeral URLSession: no cookies, no cache, ClawBar's User-Agent on every request.
final class URLSessionHTTP: HTTPFetching {
    private let session: URLSession

    /// `protocolClasses` lets tests stand in for the network.
    init(protocolClasses: [AnyClass] = []) {
        let c = URLSessionConfiguration.ephemeral
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.protocolClasses = protocolClasses + (c.protocolClasses ?? [])
        session = URLSession(configuration: c)
    }

    static func request(_ url: URL, timeout: TimeInterval) -> URLRequest {
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        r.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        return r
    }

    func get(_ url: URL, timeout: TimeInterval) async throws -> Data {
        let request = Self.request(url, timeout: timeout), session = session
        // URLRequest's timeout only bounds the gaps between packets; the deadline bounds the whole download.
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { try await session.data(for: request) }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else { throw HTTPStatusError(url: url, status: status) }
        return data
    }
}
