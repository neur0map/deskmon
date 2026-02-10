import SwiftUI

struct GaugeCardView: View {
    let title: String
    let value: String
    let percent: Double
    let icon: String
    let subtitle: String
    var tint: Color = Theme.accent
    var tintLight: Color? = nil

    private var gaugeColor: Color {
        if percent > 90 { return Theme.critical }
        if percent > 75 { return Theme.warning }
        return tint
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(max(percent / 100, 0), 1))
                    .stroke(gaugeColor.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.6), value: percent)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint.opacity(0.8))
                    Text(value)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 100, height: 100)

            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .cardStyle(cornerRadius: 16)
    }
}
