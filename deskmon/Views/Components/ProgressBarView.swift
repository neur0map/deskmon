import SwiftUI

struct ProgressBarView: View {
    let value: Double
    var maxValue: Double = 100
    var tint: Color = Theme.accent
    var tintLight: Color? = nil

    private var fraction: Double {
        min(max(value / maxValue, 0), 1)
    }

    private var barFill: some ShapeStyle {
        let percent = fraction * 100
        if percent > 90 {
            return AnyShapeStyle(
                LinearGradient(colors: [Theme.critical, Theme.critical.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        if percent > 75 {
            return AnyShapeStyle(
                LinearGradient(colors: [Theme.warning, Theme.warning.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        let end = tintLight ?? tint.opacity(0.6)
        return AnyShapeStyle(
            LinearGradient(colors: [tint, end],
                           startPoint: .leading, endPoint: .trailing)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.cardBorder)

                Capsule()
                    .fill(barFill)
                    .frame(width: geo.size.width * fraction)
                    .animation(.smooth(duration: 0.5), value: fraction)
            }
        }
        .frame(height: 6)
    }
}
