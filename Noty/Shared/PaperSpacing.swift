import NotyCanvas
import NotyCore
import SwiftUI

/// How dense the lines, squares and dots of a notebook are. Each notebook
/// keeps its own spacing; new notebooks start from the one in Settings.
enum PaperSpacing {
    static let pointsPerMillimeter = 72 / 25.4
    /// Steps of the slider, in millimeters.
    static let step = 0.5

    static func settingsKey(for style: PaperStyle) -> String {
        "paperSpacing.\(style.rawValue)"
    }

    /// The spacing chosen in Settings for new notebooks, in page points;
    /// `nil` for blank paper or when it was never changed.
    static func defaultValue(for style: PaperStyle) -> Double? {
        guard style != .blank else { return nil }
        let value = UserDefaults.standard.double(forKey: settingsKey(for: style))
        return value > 0 ? value : nil
    }

    static func millimeters(_ points: Double) -> Double {
        points / pointsPerMillimeter
    }

    static func points(_ millimeters: Double) -> Double {
        millimeters * pointsPerMillimeter
    }

    static var millimeterRange: ClosedRange<Double> {
        let lower = (millimeters(PaperRenderer.spacingRange.lowerBound) / step).rounded(.up) * step
        let upper = (millimeters(PaperRenderer.spacingRange.upperBound) / step).rounded(.down) * step
        return lower...upper
    }
}

extension PaperStyle {
    /// What the spacing measures for this paper.
    var spacingTitle: LocalizedStringKey {
        switch self {
        case .blank: "Spacing"
        case .lined: "Line Spacing"
        case .grid: "Square Size"
        case .dotted: "Dot Spacing"
        }
    }
}

/// A slider for the spacing of lines, squares or dots, in millimeters.
/// `spacing` is in page points; `nil` means the style's default.
struct PaperSpacingSlider: View {
    let style: PaperStyle
    @Binding var spacing: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(style.spacingTitle)
                Spacer()
                Text(verbatim: millimeters.formatted(.number.precision(.fractionLength(1))) + " mm")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: millimeterBinding, in: PaperSpacing.millimeterRange, step: PaperSpacing.step) {
                Text(style.spacingTitle)
            } minimumValueLabel: {
                Image(systemName: "square.grid.4x3.fill")
                    .imageScale(.small)
                    .accessibilityLabel(Text("Denser"))
            } maximumValueLabel: {
                Image(systemName: "square.grid.2x2")
                    .imageScale(.small)
                    .accessibilityLabel(Text("Wider"))
            }
        }
    }

    private var millimeters: Double {
        PaperSpacing.millimeters(spacing ?? PaperRenderer.defaultSpacing(for: style))
    }

    private var millimeterBinding: Binding<Double> {
        Binding {
            millimeters
        } set: { newValue in
            spacing = PaperSpacing.points(newValue)
        }
    }
}
