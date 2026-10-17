import CoreGraphics
import Foundation

public enum SkyPhase: String, Sendable, CaseIterable {
    case dawn, day, dusk, night
}

/// Developer-mode overrides of the sky.
public struct SkyDevState: Sendable, Hashable {
    public var phase: SkyPhase?
    /// A forced WMO code; nil = live weather.
    public var weatherCode: Int?

    public init(phase: SkyPhase? = nil, weatherCode: Int? = nil) {
        self.phase = phase
        self.weatherCode = weatherCode
    }

    public var isForced: Bool { phase != nil || weatherCode != nil }
}

/// The weather the sky draws.
public struct SkyWeather: Sendable, Hashable {
    public var code: Int
    public var windKmh: Double

    public init(code: Int, windKmh: Double) {
        self.code = code
        self.windKmh = windKmh
    }
}

public struct SkyInputs: Sendable, Hashable {
    public var now: Date
    /// The location's zone: the time of day and the sun times are read in it.
    public var timeZone: TimeZone
    public var sun: SunTimes
    /// nil draws a clear sky with an 8 km/h wind.
    public var weather: SkyWeather?
    /// For the moon's hemisphere.
    public var latitude: Double
    public var forcedPhase: SkyPhase?

    public init(now: Date, timeZone: TimeZone, sun: SunTimes, weather: SkyWeather?, latitude: Double, forcedPhase: SkyPhase?) {
        self.now = now
        self.timeZone = timeZone
        self.sun = sun
        self.weather = weather
        self.latitude = latitude
        self.forcedPhase = forcedPhase
    }
}

/// One tick of the sky, in base units with the origin at the sky's top-left.
public struct SkyFrame: Sendable, Equatable {
    /// The vertical background gradient.
    public var top: RGBA
    public var bottom: RGBA
    /// Sprites in z-order (stars, moon, glow, sun, clouds, fog, rain, snow, ground, flash),
    /// composited as one layer at opacity 0.7.
    public var ops: [DrawOp]

    public init(top: RGBA, bottom: RGBA, ops: [DrawOp]) {
        self.top = top
        self.bottom = bottom
        self.ops = ops
    }

    public static let empty = SkyFrame(top: RGBA(a: 0, r: 0, g: 0, b: 0), bottom: RGBA(a: 0, r: 0, g: 0, b: 0), ops: [])
}
