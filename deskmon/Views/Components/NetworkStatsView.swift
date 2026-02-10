import SwiftUI

struct NetworkStatsView: View {
    let network: NetworkStats
    let history: [NetworkSample]
    let batchID: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: labels + current speeds
            HStack(spacing: 0) {
                Image(systemName: "network")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("  Network")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.download)
                        Text(ByteFormatter.formatSpeed(network.downloadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.upload)
                        Text(ByteFormatter.formatSpeed(network.uploadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }
                }
            }

            // Sparkline graph
            NetworkSparkline(history: history, batchID: batchID)
                .frame(height: 48)
        }
        .padding(10)
        .cardStyle()
    }
}

// MARK: - Sparkline

private struct NetworkSparkline: View {
    let history: [NetworkSample]
    let batchID: UInt64

    private static let batchSize = CGFloat(ServerInfo.networkBatchSize)

    /// Animated batchSize→0 progress that drives the horizontal slide.
    /// At batchSize the graph is shifted right by N steps (pre-scroll);
    /// at 0 it shows the final position with the new batch visible.
    @State private var scrollPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let visible = ServerInfo.visibleNetworkSamples // 60
            let stepX = geo.size.width / CGFloat(visible - 1)

            Canvas { context, size in
                let samples = history
                guard samples.count > 1 else {
                    let baseline = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height))
                        p.addLine(to: CGPoint(x: size.width, y: size.height))
                    }
                    context.stroke(baseline, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
                    return
                }

                let dlSmoothed = smoothed(samples.map(\.download))
                let ulSmoothed = smoothed(samples.map(\.upload))

                let peak = max(dlSmoothed.max() ?? 0, ulSmoothed.max() ?? 0)
                let ceiling = peak > 0 ? peak * 1.15 : 1

                // scrollPhase shifts the entire graph right by N steps.
                // At batchSize the new batch is hidden off-screen right;
                // as it animates to 0 the graph slides left, revealing them.
                let baseOffset = CGFloat(visible - samples.count) * stepX
                let xShift = scrollPhase * stepX
                let offsetX = baseOffset + xShift

                // Download
                let dlPath = buildCatmullRomPath(
                    samples: dlSmoothed, size: size, ceiling: ceiling,
                    stepX: stepX, offsetX: offsetX
                )
                let dlFill = buildFillPath(
                    from: dlPath, samples: dlSmoothed,
                    size: size, stepX: stepX, offsetX: offsetX
                )
                context.fill(dlFill, with: .linearGradient(
                    Gradient(colors: [Theme.download.opacity(0.3), Theme.download.opacity(0.02)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(dlPath, with: .color(Theme.download.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Upload
                let ulPath = buildCatmullRomPath(
                    samples: ulSmoothed, size: size, ceiling: ceiling,
                    stepX: stepX, offsetX: offsetX
                )
                let ulFill = buildFillPath(
                    from: ulPath, samples: ulSmoothed,
                    size: size, stepX: stepX, offsetX: offsetX
                )
                context.fill(ulFill, with: .linearGradient(
                    Gradient(colors: [Theme.upload.opacity(0.25), Theme.upload.opacity(0.02)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(ulPath, with: .color(Theme.upload.opacity(0.7)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .background(Color.white.opacity(0.03), in: .rect(cornerRadius: 6))
        .onChange(of: batchID) {
            // Jump to pre-scroll position (shifted right by batchSize steps),
            // then smoothly slide left over ~5 seconds.
            scrollPhase = Self.batchSize
            withAnimation(.linear(duration: 4.8)) {
                scrollPhase = 0
            }
        }
    }

    // MARK: - Data Smoothing

    /// Weighted moving average: [0.2, 0.6, 0.2] kernel
    private func smoothed(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        var result = [Double](repeating: 0, count: values.count)
        result[0] = values[0]
        result[values.count - 1] = values[values.count - 1]
        for i in 1..<(values.count - 1) {
            result[i] = values[i - 1] * 0.2 + values[i] * 0.6 + values[i + 1] * 0.2
        }
        return result
    }

    // MARK: - Catmull-Rom Spline Path

    private func buildCatmullRomPath(samples: [Double], size: CGSize, ceiling: Double, stepX: CGFloat, offsetX: CGFloat) -> Path {
        let points: [CGPoint] = samples.enumerated().map { i, value in
            let x = offsetX + CGFloat(i) * stepX
            let y = size.height - (CGFloat(value / ceiling) * size.height)
            return CGPoint(x: x, y: y)
        }

        return Path { path in
            guard points.count >= 2 else { return }
            path.move(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
                return
            }

            let tension: CGFloat = 0.5

            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = (i + 2) < points.count ? points[i + 2] : points[i + 1]

                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / (6 * tension),
                    y: p1.y + (p2.y - p0.y) / (6 * tension)
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / (6 * tension),
                    y: p2.y - (p3.y - p1.y) / (6 * tension)
                )

                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    // MARK: - Fill Path

    private func buildFillPath(from linePath: Path, samples: [Double], size: CGSize, stepX: CGFloat, offsetX: CGFloat) -> Path {
        var path = linePath
        let lastX = offsetX + CGFloat(samples.count - 1) * stepX
        let firstX = offsetX
        path.addLine(to: CGPoint(x: lastX, y: size.height))
        path.addLine(to: CGPoint(x: firstX, y: size.height))
        path.closeSubpath()
        return path
    }
}
