import Foundation
import ClawBarShared

/// weather.ps1's data side: the place (configured or by IP), Open-Meteo, met.no as the fallback.
@MainActor
final class WeatherService {
    private(set) var weather: WeatherSnapshot?
    /// From the IP lookup.
    private(set) var geo: Place?
    /// After a fetch changed `weather` or `geo`.
    var onUpdate: (() -> Void)?

    private let http: any HTTPFetching
    private let clock: () -> Date
    /// Failures; the controller logs each distinct one once.
    var log: (String) -> Void
    private var config = Config()
    private var placeKey: String?
    private var geoTry: Date?
    private var wxTry: Date?
    /// met.no is used since then; Open-Meteo gets another chance an hour later (the original's switch was sticky).
    private var fallbackSince: Date?
    private var task: Task<Void, Never>?
    private var stopped = false

    nonisolated static let timeout: TimeInterval = 15
    nonisolated static let geoRetry: TimeInterval = 600
    nonisolated static let openMeteoRetry: TimeInterval = 3600

    init(http: any HTTPFetching, clock: @escaping () -> Date, log: @escaping (String) -> Void) {
        self.http = http
        self.clock = clock
        self.log = log
    }

    /// The configured coordinates when both are set, else the IP location.
    var place: Place? {
        if let lat = config.weatherLat, let lon = config.weatherLon { return Place(lat: lat, lon: lon) }
        return geo
    }

    func tick(now: Date, config: Config) {
        self.config = config
        let key = "\(config.weatherLat.map { "\($0)" } ?? "")|\(config.weatherLon.map { "\($0)" } ?? "")"
        if key != placeKey {
            placeKey = key
            wxTry = nil
        }
        start(now: now)
    }

    func shutdown() {
        stopped = true
        task?.cancel()
        task = nil
    }

    private func start(now: Date) {
        guard !stopped, task == nil, config.showMascot, config.showSky,
              Cadence.due(last: wxTry, interval: TimeInterval(config.weatherIntervalSeconds), now: now)
        else { return }
        guard let place else {
            // No coordinates yet: look the place up first, without touching the weather's attempt time.
            guard Cadence.due(last: geoTry, interval: Self.geoRetry, now: now) else { return }
            geoTry = now
            let url = Self.geoURL(config.lang)
            run { [http] in try await http.get(url, timeout: Self.timeout) } done: { me, data in
                guard let data, let p = Self.parseGeo(data) else { return me.log("weather: no location from \(url.host ?? "")") }
                me.geo = p
                me.wxTry = nil
                me.onUpdate?()
                me.start(now: me.clock())
            }
            return
        }
        wxTry = now
        if let since = fallbackSince, !Cadence.due(last: since, interval: Self.openMeteoRetry, now: now) {
            let url = Self.metNoURL(place)
            run { [http] in try await http.get(url, timeout: Self.timeout) } done: { me, data in
                guard let data, let wx = Self.parseMetNo(data, now: me.clock()) else { return me.log("weather: met.no failed") }
                me.weather = wx
                me.onUpdate?()
            }
        } else {
            let url = Self.openMeteoURL(place)
            run { [http] in try await http.get(url, timeout: Self.timeout) } done: { me, data in
                guard let data, let wx = Self.parseOpenMeteo(data, now: me.clock()) else {
                    // Unreachable or refused: met.no right away.
                    me.log("weather: Open-Meteo failed, using met.no")
                    me.fallbackSince = me.clock()
                    me.wxTry = nil
                    me.start(now: me.clock())
                    return
                }
                me.fallbackSince = nil
                me.weather = wx
                me.onUpdate?()
            }
        }
    }

    /// One request at a time, geo or weather, as in the original.
    private func run(
        _ fetch: @escaping @Sendable () async throws -> Data, done: @escaping (WeatherService, Data?) -> Void
    ) {
        task = Task { [weak self] in
            let data = try? await fetch()
            guard let self, !Task.isCancelled, !self.stopped else { return }
            self.task = nil
            done(self, data)
        }
    }

    /// One lookup without the state machine, for diagnostics: the place, then Open-Meteo, then met.no.
    nonisolated static func fetchOnce(
        config: Config, http: any HTTPFetching, now: @Sendable () -> Date
    ) async -> (place: Place?, weather: WeatherSnapshot?, provider: String?) {
        var place: Place?
        if let lat = config.weatherLat, let lon = config.weatherLon {
            place = Place(lat: lat, lon: lon)
        } else if let data = try? await http.get(geoURL(config.lang), timeout: timeout) {
            place = parseGeo(data)
        }
        guard let place else { return (nil, nil, nil) }
        if let data = try? await http.get(openMeteoURL(place), timeout: timeout), let wx = parseOpenMeteo(data, now: now()) {
            return (place, wx, "Open-Meteo")
        }
        let data = try? await http.get(metNoURL(place), timeout: timeout)
        return (place, data.flatMap { parseMetNo($0, now: now()) }, "met.no")
    }

    // MARK: - Requests

    nonisolated static func geoURL(_ lang: Lang) -> URL { URL(string: "https://ipwho.is/?lang=\(lang.rawValue)")! }

    nonisolated static func openMeteoURL(_ p: Place) -> URL {
        URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(plain(p.lat))&longitude=\(plain(p.lon))"
            + "&current=weather_code,temperature_2m,wind_speed_10m&daily=sunrise,sunset&timezone=auto&forecast_days=1")!
    }

    /// met.no asks for at most four decimals.
    nonisolated static func metNoURL(_ p: Place) -> URL {
        URL(string: String(format: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f", p.lat, p.lon))!
    }

    /// Full precision without an exponent, like .NET's invariant ToString: 48 not 48.0, 0.00001 not 1e-05.
    nonisolated static func plain(_ x: Double) -> String {
        var s = "\(x)"
        if s.contains("e") {
            s = String(format: "%.12f", x)
            while s.hasSuffix("0") { s.removeLast() }
        }
        if s.hasSuffix(".0") { s.removeLast(2) }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: - Answers

    nonisolated static func parseGeo(_ data: Data) -> Place? {
        guard let j = JSONFile.object(from: data), Lenient.bool(j["success"]) != false,
              let lat = Lenient.double(j["latitude"]), let lon = Lenient.double(j["longitude"])
        else { return nil }
        let city = Lenient.string(j["city"]).flatMap { $0.isEmpty ? nil : $0 }
        let zone = Lenient.string((j["timezone"] as? [String: Any])?["id"]).flatMap { $0.isEmpty ? nil : $0 }
        return Place(lat: lat, lon: lon, city: city, timeZoneID: zone)
    }

    /// nil without `current`, which is what sends the original to met.no.
    nonisolated static func parseOpenMeteo(_ data: Data, now: Date) -> WeatherSnapshot? {
        guard let j = JSONFile.object(from: data), let cur = j["current"] as? [String: Any] else { return nil }
        let daily = j["daily"] as? [String: Any]
        func minutes(_ key: String) -> Double? {
            guard let s = Lenient.string((daily?[key] as? [Any])?.first), let m = Rx.first(timeOfDay, in: s),
                  let h = Double(m[1] ?? ""), let mi = Double(m[2] ?? "")
            else { return nil }
            return h * 60 + mi
        }
        return WeatherSnapshot(
            code: Lenient.int(cur["weather_code"]) ?? 0,
            tempC: Lenient.double(cur["temperature_2m"]) ?? 0,
            windKmh: Lenient.double(cur["wind_speed_10m"]) ?? 0,
            sunriseMin: minutes("sunrise"), sunsetMin: minutes("sunset"),
            timeZoneID: Lenient.string(j["timezone"]).flatMap { $0.isEmpty ? nil : $0 },
            at: now
        )
    }

    nonisolated static func parseMetNo(_ data: Data, now: Date) -> WeatherSnapshot? {
        guard let j = JSONFile.object(from: data),
              let series = (j["properties"] as? [String: Any])?["timeseries"] as? [[String: Any]],
              let d = series.first?["data"] as? [String: Any]
        else { return nil }
        let summary = (d["next_1_hours"] as? [String: Any])?["summary"] as? [String: Any]
        let details = (d["instant"] as? [String: Any])?["details"] as? [String: Any]
        return WeatherSnapshot(
            code: metNoCode(Lenient.string(summary?["symbol_code"]) ?? ""),
            tempC: Lenient.double(details?["air_temperature"]) ?? 0,
            // m/s to km/h, as Open-Meteo reports it
            windKmh: 3.6 * (Lenient.double(details?["wind_speed"]) ?? 0),
            at: now
        )
    }

    /// "lightrainshowers_day" → 80: weather.ps1 ConvertFrom-MetNo, first rule wins.
    nonisolated static func metNoCode(_ symbol: String) -> Int {
        let s = Rx.replace(daySuffix, in: symbol.lowercased(), with: "")
        let level = s.hasPrefix("light") ? 0 : s.hasPrefix("heavy") ? 2 : 1
        let showers = s.contains("showers")
        if s.contains("thunder") { return 95 }
        if s.contains("snow") { return showers ? [85, 85, 86][level] : [71, 73, 75][level] }
        if s.contains("sleet") { return level == 2 ? 67 : 66 }
        if s.contains("rain") { return showers ? [80, 81, 82][level] : [61, 63, 65][level] }
        if s.hasPrefix("fog") { return 45 }
        if s.hasPrefix("cloudy") { return 3 }
        if s.hasPrefix("partlycloudy") { return 2 }
        if s.hasPrefix("fair") { return 1 }
        if s.hasPrefix("clearsky") { return 0 }
        return 3
    }

    private nonisolated static let daySuffix = Rx.make(#"_(day|night|polartwilight)$"#)
    private nonisolated static let timeOfDay = Rx.make(#"^\d{4}-\d{2}-\d{2}T(\d{2}):(\d{2})"#)
}
