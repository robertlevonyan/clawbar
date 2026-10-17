import ClawBarShared

/// sky.ps1's palettes, colours and pixel shapes.
enum SkyArt {
    struct Palette {
        var top: RGBA
        var bottom: RGBA
        var light: Double
    }

    static let night = Palette(top: RGBA("#00304A8C"), bottom: RGBA("#1A304A8C"), light: 0.0)
    static let dawn = Palette(top: RGBA("#00404E8A"), bottom: RGBA("#33E08A66"), light: 0.5)
    static let day = Palette(top: RGBA("#004A8CCB"), bottom: RGBA("#2E6FA8D8"), light: 1.0)
    static let dusk = Palette(top: RGBA("#00383070"), bottom: RGBA("#33D86A50"), light: 0.5)

    static let sunHigh = RGBA("#FFFDE68A")
    static let sunLow = RGBA("#FFFB923C")
    static let snowDay = RGBA("#80DDE4EC")
    static let snowNight = RGBA("#50A1A8B5")
    static let cloudDay = RGBA("#FFB4B4BC")
    static let cloudNight = RGBA("#FF5E5E68")
    static let cloudRain = RGBA("#FF52525B")

    static let star = RGBA("#FFF8FAFC")
    static let moonDark = RGBA("#2EE5E7EB")
    static let moonLit = RGBA("#FFF1F5F9")
    static let glowInner = RGBA("#40FDE68A")
    static let glowOuter = RGBA("#00FDE68A")
    static let drop = RGBA("#8093C5FD")
    static let flake = RGBA("#C0E4E4E7")
    static let flash = RGBA("#FFF8FAFC")
    static let fogStops = [
        GradientStop(location: 0, color: RGBA("#00E5E7EB")),
        GradientStop(location: 0.5, color: RGBA("#FFE5E7EB")),
        GradientStop(location: 1, color: RGBA("#00E5E7EB")),
    ]

    static let sun = ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."]
    static let sunPx = 1.4
    static let moonPx = 1.3
    static let cloudPx = 2.0
    static let clouds: [[String]] = [
        ["....###.....", "..#######...", ".##########.", "############"],
        ["..###...", ".######.", "########"],
        ["...##.##..", ".########.", "##########"],
    ]

    /// Opacity by `flash − 1`: in time order 0.04, 0.1, 0.25, 0, 0.05, 0.18, 0, a double flash.
    static let flashOpacity = [0, 0.18, 0.05, 0, 0.25, 0.1, 0.04]
}

/// PowerShell's [int][math]::Round, without trapping on a value that is not a number.
func whole(_ x: Double) -> Int {
    let r = x.rounded(.toNearestOrEven)
    return r.isFinite && abs(r) < 1e15 ? Int(r) : 0
}
