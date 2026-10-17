import Observation
import SwiftUI
import Testing
@testable import ClawBar
import ClawBarShared

@Observable
final class MeasureBox {
    var text: CGRect = .zero
    var baseline: CGRect = .zero
}

/// A zero-height marker aligned to the text's first baseline reports where that baseline is.
private struct Measured: View {
    let box: MeasureBox
    let text: String
    let size: Double
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Color.clear.frame(width: 1, height: 0)
                .alignmentGuide(.firstTextBaseline) { _ in 0 }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("m")) } action: { box.baseline = $0 }
            WText(text, size, color: Palette.white, wraps: true)
                .frame(width: 400)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("m")) } action: { box.text = $0 }
        }
        .coordinateSpace(.named("m"))
    }
}

@MainActor
@Suite struct TextMetricsTests {
    func measure(_ text: String, size: Double, k: Double = 1) -> MeasureBox {
        let box = MeasureBox()
        let r = ImageRenderer(content: Measured(box: box, text: text, size: size).environment(\.uiScale, k))
        r.scale = 2
        _ = r.cgImage
        return box
    }

    @Test(arguments: [8.0, 9.0, 10.5, 11.0, 14.0, 30.0])
    func aTextBlockHasSegoesLineBoxAndBaseline(size: Double) {
        let m = measure("Ag", size: size)
        // Half a point of slack: SwiftUI rounds text frames to the 2× pixel grid.
        #expect(abs(m.text.height - WPFLineBox.height * size) <= 0.5)
        #expect(abs((m.baseline.minY - m.text.minY) - WPFLineBox.baseline * size) <= 0.5)
    }

    @Test func wrappedLinesKeepWPFsPitch() {
        let m = measure("Ag\nAg\nAg", size: 10.5)
        #expect(abs(m.text.height - 3 * WPFLineBox.height * 10.5) <= 0.5)
    }

    @Test func everythingScalesWithK() {
        let m = measure("Ag", size: 10, k: 2)
        #expect(abs(m.text.height - WPFLineBox.height * 20) <= 0.5)
    }
}
