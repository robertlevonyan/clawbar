import Foundation

/// What a WMO weather code looks like in the sky.
public struct WeatherKind: Sendable, Hashable {
    /// The `wx.<id>` key; "code" for an unknown code.
    public var id: String
    /// Cloud cover 0...1.
    public var cover: Double
    public var fog: Bool
    public var storm: Bool
    /// Rain drops and snowflakes at this intensity.
    public var rain: Int
    public var snow: Int

    public init(id: String, cover: Double, fog: Bool = false, storm: Bool = false, rain: Int = 0, snow: Int = 0) {
        self.id = id
        self.cover = cover
        self.fog = fog
        self.storm = storm
        self.rain = rain
        self.snow = snow
    }
}

/// weather.ps1's $WeatherKinds.
public enum WeatherKinds {
    private struct Group: Sendable {
        var codes: [Int]
        var kind: WeatherKind
    }

    private static let groups: [Group] = [
        Group(codes: [0], kind: WeatherKind(id: "clear", cover: 0.0)),
        Group(codes: [1], kind: WeatherKind(id: "mostlyClear", cover: 0.2)),
        Group(codes: [2], kind: WeatherKind(id: "partly", cover: 0.5)),
        Group(codes: [3], kind: WeatherKind(id: "overcast", cover: 0.85)),
        Group(codes: [45, 48], kind: WeatherKind(id: "fog", cover: 0.7, fog: true)),
        Group(codes: [51, 53, 55], kind: WeatherKind(id: "drizzle", cover: 0.8, rain: 6)),
        Group(codes: [56, 57], kind: WeatherKind(id: "iceDrizzle", cover: 0.8, rain: 6)),
        Group(codes: [61, 63, 65], kind: WeatherKind(id: "rain", cover: 0.9, rain: 12)),
        Group(codes: [66, 67], kind: WeatherKind(id: "iceRain", cover: 0.9, rain: 12)),
        Group(codes: [71, 73, 75], kind: WeatherKind(id: "snow", cover: 0.85, snow: 10)),
        Group(codes: [77], kind: WeatherKind(id: "grains", cover: 0.85, snow: 8)),
        Group(codes: [80, 81, 82], kind: WeatherKind(id: "showers", cover: 0.85, rain: 16)),
        Group(codes: [85, 86], kind: WeatherKind(id: "snowShowers", cover: 0.9, snow: 14)),
        Group(codes: [95, 96, 99], kind: WeatherKind(id: "storm", cover: 1.0, storm: true, rain: 16)),
    ]

    /// Three-code groups are light, moderate and heavy: counts × 0.6, 1.0, 1.35, banker's-rounded.
    public static func kind(code: Int) -> WeatherKind {
        for g in groups {
            guard let i = g.codes.firstIndex(of: code) else { continue }
            let mul = g.codes.count == 3 ? [0.6, 1.0, 1.35][i] : 1.0
            var k = g.kind
            k.rain = Int((Double(k.rain) * mul).rounded(.toNearestOrEven))
            k.snow = Int((Double(k.snow) * mul).rounded(.toNearestOrEven))
            return k
        }
        return WeatherKind(id: "code", cover: 0.5)
    }

    public static func name(code: Int, lang: Lang) -> String {
        let k = kind(code: code)
        if k.id != "code", let key = L10nKey(rawValue: "wx.\(k.id)") { return L10n.t(key, lang) }
        return L10n.t(.wxCode, lang, code)
    }

    /// The developer menu's weather list, after "live weather".
    public static let devMenuCodes = [0, 2, 3, 45, 53, 63, 82, 95, 73]
}

public struct SunTimes: Sendable, Hashable {
    /// Minutes after local midnight.
    public var sunrise: Double
    public var sunset: Double

    public init(sunrise: Double, sunset: Double) {
        self.sunrise = sunrise
        self.sunset = sunset
    }

    /// 07:00 and 19:00, when nothing better is known.
    public static let fallback = SunTimes(sunrise: 420, sunset: 1140)
}

public enum SunCalc {
    /// The NOAA approximation of weather.ps1 Get-SunCalc, in `timeZone`'s clock on `date`.
    /// Polar day and night are clamped, so sunrise can come out after sunset; callers guard that.
    public static func noaa(lat: Double, lon: Double, date: Date, timeZone: TimeZone) -> SunTimes {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        let gm = 2 * Double.pi / 365 * (dayOfYear - 0.5)
        let eq = 229.18 * (0.000075 + 0.001868 * cos(gm) - 0.032077 * sin(gm)
            - 0.014615 * cos(2 * gm) - 0.040849 * sin(2 * gm))
        let dec = 0.006918 - 0.399912 * cos(gm) + 0.070257 * sin(gm)
            - 0.006758 * cos(2 * gm) + 0.000907 * sin(2 * gm)
            - 0.002697 * cos(3 * gm) + 0.00148 * sin(3 * gm)
        let la = lat * Double.pi / 180
        var c = cos(90.833 * Double.pi / 180) / (cos(la) * cos(dec)) - tan(la) * tan(dec)
        c = max(-0.999, min(0.999, c))
        let ha = acos(c) * 180 / Double.pi
        let tz = Double(timeZone.secondsFromGMT(for: date)) / 60
        func wrap(_ m: Double) -> Double {
            (m.truncatingRemainder(dividingBy: 1440) + 1440).truncatingRemainder(dividingBy: 1440)
        }
        return SunTimes(sunrise: wrap(720 - 4 * (lon + ha) - eq + tz), sunset: wrap(720 - 4 * (lon - ha) - eq + tz))
    }
}
