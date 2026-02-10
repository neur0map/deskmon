import SwiftUI

struct ContainerTableView: View {
    let containers: [DockerContainer]
    var selectedID: String? = nil
    var onSelect: ((DockerContainer) -> Void)? = nil

    @State private var hoveredID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "Containers", count: containers.count)
                .padding(.horizontal, 4)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    Text("")
                        .frame(width: 10)
                    Text("Name")
                    Text("Image")
                    Text("CPU")
                        .frame(width: 60, alignment: .trailing)
                    Text("Memory")
                        .frame(width: 80, alignment: .trailing)
                    Text("Status")
                        .frame(width: 70, alignment: .trailing)
                    Text("")
                        .frame(width: 14)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)

                ForEach(containers) { container in
                    let isSelected = container.id == selectedID
                    let isHovered = hoveredID == container.id
                    GridRow {
                        Circle()
                            .fill(container.status.color)
                            .frame(width: 8, height: 8)

                        Text(container.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)

                        Text(shortImage(container.image))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if container.status == .running {
                            Text(String(format: "%.1f%%", container.cpuPercent))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .trailing)

                            Text(String(format: "%.0f MB", container.memoryUsageMB))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        } else {
                            Text("-")
                                .foregroundStyle(.quaternary)
                                .frame(width: 60, alignment: .trailing)
                            Text("-")
                                .foregroundStyle(.quaternary)
                                .frame(width: 80, alignment: .trailing)
                        }

                        Text(container.status.label)
                            .font(.caption)
                            .foregroundStyle(container.status.color)
                            .frame(width: 70, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(isHovered || isSelected ? .secondary : .quaternary)
                            .frame(width: 14)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        isSelected ? Theme.accent.opacity(0.1) :
                        (isHovered ? Color.white.opacity(0.04) : .clear),
                        in: .rect(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Theme.accent.opacity(0.25) : Theme.cardBorder, lineWidth: 1)
                    )
                    .background(Theme.cardBackground, in: .rect(cornerRadius: 8))
                    .contentShape(.rect)
                    .onTapGesture {
                        onSelect?(container)
                    }
                    .onHover { isHovering in
                        hoveredID = isHovering ? container.id : nil
                    }
                }
            }
        }
        .padding(14)
        .cardStyle(cornerRadius: 16)
    }

    private func shortImage(_ image: String) -> String {
        if let last = image.split(separator: "/").last {
            return String(last)
        }
        return image
    }
}
