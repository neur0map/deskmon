import SwiftUI

struct ContainerRowView: View {
    let container: DockerContainer
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(container.status.color)
                .frame(width: 8, height: 8)

            Text(container.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer()

            if container.status == .running {
                Text(String(format: "%.1f%%", container.cpuPercent))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .contentTransition(.numericText())

                Text(String(format: "%.0f MB", container.memoryUsageMB))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                    .contentTransition(.numericText())
            } else {
                Text(container.status.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .cardStyle(cornerRadius: 8)
        .contentShape(.rect)
        .onTapGesture {
            onTap?()
        }
    }
}
