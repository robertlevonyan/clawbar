import Foundation

/// The one source of randomness for Clawd and the sky, injected so tests and recordings replay exactly.
public protocol RandomSource: AnyObject {
    /// Uniform in `0 ..< 1`.
    func nextDouble() -> Double
    /// Uniform in `0 ..< upperBound`; 0 when `upperBound <= 1`.
    func nextInt(_ upperBound: Int) -> Int
}

public final class SystemRandomSource: RandomSource {
    private var generator = SystemRandomNumberGenerator()

    public init() {}

    public func nextDouble() -> Double { Double.random(in: 0 ..< 1, using: &generator) }

    public func nextInt(_ upperBound: Int) -> Int {
        upperBound > 1 ? Int.random(in: 0 ..< upperBound, using: &generator) : 0
    }
}

/// SplitMix64.
public final class SeededRandomSource: RandomSource {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public func nextDouble() -> Double { Double(next() >> 11) * 0x1.0p-53 }

    public func nextInt(_ upperBound: Int) -> Int {
        upperBound > 1 ? Int(next() % UInt64(upperBound)) : 0
    }
}
