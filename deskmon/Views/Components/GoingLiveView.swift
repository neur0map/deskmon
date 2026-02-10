import SwiftUI

struct GoingLiveView: View {
    @State private var countdown = 3
    @State private var progress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder, lineWidth: 3)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Theme.accent.gradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text("\(countdown)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(Theme.accent)
            }
            .scaleEffect(pulseScale)

            VStack(spacing: 6) {
                Text("Going live")
                    .font(.headline)
                Text("Establishing real-time connection...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            withAnimation(.linear(duration: 3)) {
                progress = 1
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }

            try? await Task.sleep(for: .seconds(1))
            withAnimation(.snappy) { countdown = 2 }
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.snappy) { countdown = 1 }
        }
    }
}
