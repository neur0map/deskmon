import SwiftUI

struct ContainerListView: View {
    let containers: [DockerContainer]
    var onSelectContainer: ((DockerContainer) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Containers", count: containers.count)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                Spacer()
                Text("CPU")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
                Text("MEM")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 52, alignment: .trailing)
                // Spacer for chevron
                Color.clear.frame(width: 16)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 3) {
                ForEach(containers) { container in
                    ContainerRowView(container: container) {
                        onSelectContainer?(container)
                    }
                }
            }
        }
        .padding(10)
        .cardStyle()
    }
}
