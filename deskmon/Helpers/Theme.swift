import SwiftUI
import AppKit

// MARK: - Subtle Glass Background

struct SubtleGlassBackground: NSViewRepresentable {
    var opacity: Double = 0.15

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = CGFloat(opacity)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.alphaValue = CGFloat(opacity)
    }
}

enum Theme {
    // MARK: - Brand

    static let accent = Color(red: 0.976, green: 0.388, blue: 0.008) // Home Depot orange

    // MARK: - Surfaces (OLED Dark)

    static let background = Color.black
    static let cardBackground = Color(white: 0.07)
    static let cardBorder = Color(white: 0.14)

    // MARK: - Graph Colors

    static let cpu = Color(red: 0.976, green: 0.388, blue: 0.008)
    static let cpuLight = Color(red: 0.984, green: 0.573, blue: 0.235)

    static let memory = Color(red: 0.024, green: 0.714, blue: 0.831)
    static let memoryLight = Color(red: 0.133, green: 0.827, blue: 0.933)

    static let disk = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let diskLight = Color(red: 0.753, green: 0.518, blue: 0.988)

    // MARK: - Gradients

    static let cpuGradient = LinearGradient(
        colors: [cpu, cpuLight],
        startPoint: .leading, endPoint: .trailing
    )
    static let memoryGradient = LinearGradient(
        colors: [memory, memoryLight],
        startPoint: .leading, endPoint: .trailing
    )
    static let diskGradient = LinearGradient(
        colors: [disk, diskLight],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: - Network

    static let download = Color(red: 0.024, green: 0.714, blue: 0.831)
    static let upload = Color(red: 0.063, green: 0.725, blue: 0.506)

    // MARK: - Status

    static let healthy = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let critical = Color(red: 0.957, green: 0.243, blue: 0.369)
}

// MARK: - Card Styles

extension View {
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Theme.cardBackground, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }

    func tintedCardStyle(cornerRadius: CGFloat = 12, tint: Color) -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.cardBackground)
                    RoundedRectangle(cornerRadius: cornerRadius).fill(tint.opacity(0.08))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
    }

    func innerPanel(cornerRadius: CGFloat = 14) -> some View {
        self
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Button Styles

struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.cardBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct DarkProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

extension ButtonStyle where Self == DarkButtonStyle {
    static var dark: DarkButtonStyle { DarkButtonStyle() }
}

extension ButtonStyle where Self == DarkProminentButtonStyle {
    static var darkProminent: DarkProminentButtonStyle { DarkProminentButtonStyle() }
}
