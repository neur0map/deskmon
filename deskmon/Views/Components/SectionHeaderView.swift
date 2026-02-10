import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}
