import SwiftUI

struct NetworkStatsView: View {
    let network: NetworkStats

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.download)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(ByteFormatter.formatSpeed(network.downloadBytesPerSec))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(Theme.upload)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(ByteFormatter.formatSpeed(network.uploadBytesPerSec))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(10)
        .cardStyle()
    }
}
