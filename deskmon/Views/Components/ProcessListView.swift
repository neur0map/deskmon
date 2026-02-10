import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessInfo]
    var selectedPID: Int32? = nil
    var onSelect: ((ProcessInfo) -> Void)?

    @State private var hoveredPID: Int32?

    private var sortedProcesses: [ProcessInfo] {
        processes.sorted {
            if abs($0.cpuPercent - $1.cpuPercent) < 0.05 {
                return $0.pid < $1.pid
            }
            return $0.cpuPercent > $1.cpuPercent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Top Processes", count: processes.count)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                Text("PID")
                    .frame(width: 48, alignment: .leading)
                Spacer()
                Text("CPU")
                    .frame(width: 48, alignment: .trailing)
                Text("MEM")
                    .frame(width: 56, alignment: .trailing)
                if onSelect != nil {
                    Spacer().frame(width: 20)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Array(sortedProcesses.enumerated()), id: \.element.pid) { index, process in
                    let isSelected = selectedPID == process.pid
                    let isHovered = hoveredPID == process.pid

                    processRow(process, rank: index + 1)
                        .background(
                            isSelected ? Theme.accent.opacity(0.1) :
                            (isHovered ? Color.white.opacity(0.04) : .clear),
                            in: .rect(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? Theme.accent.opacity(0.25) : .clear, lineWidth: 1)
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            onSelect?(process)
                        }
                        .onHover { isHovering in
                            hoveredPID = isHovering ? process.pid : nil
                        }

                    if index < sortedProcesses.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
            .cardStyle(cornerRadius: 8)
        }
        .padding(10)
        .cardStyle()
    }

    private func processRow(_ process: ProcessInfo, rank: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.quaternary)
                .frame(width: 14, alignment: .trailing)

            Text(process.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(process.cpuPercent > 50 ? Theme.critical : .secondary)
                .frame(width: 48, alignment: .trailing)
                .contentTransition(.numericText())

            Text(String(format: "%.0f MB", process.memoryMB))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
                .contentTransition(.numericText())

            if onSelect != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(hoveredPID == process.pid ? .secondary : .quaternary)
                    .frame(width: 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
