import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let percent: Double
    let icon: String
    var tint: Color = Theme.accent
    var tintLight: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
            }
            ProgressBarView(value: percent, tint: tint, tintLight: tintLight)
        }
        .padding(10)
        .cardStyle()
    }
}
