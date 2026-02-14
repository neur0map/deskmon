import SwiftUI

struct NetworkStatsView: View {
    let network: NetworkReport
    let history: [NetworkSample]

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
                        Text(ByteFormatter.formatSpeed(network.physical.downloadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.upload)
                        Text(ByteFormatter.formatSpeed(network.physical.uploadBytesPerSec))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                    }

                    if network.physical.hasErrors {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7))
                            Text("\(network.physical.totalDrops + network.physical.totalErrors) err")
                                .font(.caption2.monospacedDigit())
                        }
                        .foregroundStyle(Theme.critical)
                    }
                }
            }

            // Sparkline graph — continuously scrolling at 60fps
            NetworkSparkline(history: history)
                .frame(height: 48)
        }
        .padding(10)
        .cardStyle()
    }
}

// MARK: - Sparkline

/// Renders a continuously-scrolling network sparkline.
///
/// Uses `TimelineView(.animation)` to redraw every display frame (~60fps).
/// Each sample's X position is computed from wall-clock time, so the graph
/// drifts left at a constant rate — like a chart recorder. No discrete
/// "refresh" moments are visible.
private struct NetworkSparkline: View {
    let history: [NetworkSample]

    private static let windowDuration = ServerInfo.windowDuration // 60s visible

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

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

                let pps = size.width / CGFloat(Self.windowDuration) // pixels per second

                // Smooth raw values
                let dlSmoothed = smoothed(samples.map(\.download))
                let ulSmoothed = smoothed(samples.map(\.upload))

                let peak = max(dlSmoothed.max() ?? 0, ulSmoothed.max() ?? 0)
                let ceiling = peak > 0 ? peak * 1.15 : 1

                // Build time-based points: X = distance from right edge based on age
                func makePoints(_ values: [Double]) -> [CGPoint] {
                    values.enumerated().map { i, value in
                        let age = now - samples[i].time
                        let x = size.width - CGFloat(age) * pps
                        let y = size.height - CGFloat(value / ceiling) * size.height
                        return CGPoint(x: x, y: y)
                    }
                }

                // Download
                let dlPoints = makePoints(dlSmoothed)
                let dlPath = catmullRomPath(through: dlPoints)
                let dlFill = fillPath(from: dlPath, points: dlPoints, height: size.height)
                context.fill(dlFill, with: .linearGradient(
                    Gradient(colors: [Theme.download.opacity(0.3), Theme.download.opacity(0.02)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(dlPath, with: .color(Theme.download.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Upload
                let ulPoints = makePoints(ulSmoothed)
                let ulPath = catmullRomPath(through: ulPoints)
                let ulFill = fillPath(from: ulPath, points: ulPoints, height: size.height)
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

    // MARK: - Catmull-Rom Spline

    private func catmullRomPath(through points: [CGPoint]) -> Path {
        Path { path in
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

    private func fillPath(from linePath: Path, points: [CGPoint], height: CGFloat) -> Path {
        guard let first = points.first, let last = points.last else { return linePath }
        var path = linePath
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }
}
