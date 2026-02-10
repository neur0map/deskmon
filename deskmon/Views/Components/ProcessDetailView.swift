import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessInfo

    @Environment(ServerManager.self) private var serverManager
    @State private var isKilling = false
    @State private var showKillConfirmation = false
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection
                actionsSection
                cpuSection
                memorySection
                infoSection
                if let command = process.command, !command.isEmpty {
                    commandSection(command)
                }
            }
            .padding(16)
        }
        .alert("Kill Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Kill", role: .destructive) { performKill() }
        } message: {
            Text("Send SIGTERM to \"\(process.name)\" (PID \(process.pid))?")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.headline)
                Text("PID \(process.pid)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let user = process.user, !user.isEmpty {
                Label(user, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .tintedCardStyle(cornerRadius: 10, tint: Theme.accent)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showKillConfirmation = true
            } label: {
                HStack(spacing: 4) {
                    if isKilling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "xmark.octagon.fill")
                    }
                    Text("Kill Process")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.critical)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.critical.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isKilling)

            if let actionError {
                Text(actionError)
                    .font(.caption2)
                    .foregroundStyle(Theme.critical)
            }
        }
        .padding(12)
        .tintedCardStyle(cornerRadius: 10, tint: Theme.accent)
    }

    private func performKill() {
        actionError = nil
        isKilling = true
        Task {
            do {
                _ = try await serverManager.killProcess(pid: process.pid)
            } catch {
                actionError = error.localizedDescription
            }
            isKilling = false
        }
    }

    // MARK: - CPU

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", process.cpuPercent))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
            }

            ProgressBarView(value: process.cpuPercent, tint: Theme.cpu, tintLight: Theme.cpuLight)
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Memory

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f MB", process.memoryMB))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
            }

            ProgressBarView(value: process.memoryPercent, tint: Theme.memory, tintLight: Theme.memoryLight)

            HStack {
                Text(String(format: "%.1f%%", process.memoryPercent))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Info", systemImage: "info.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            infoRow("PID", value: "\(process.pid)")

            if let user = process.user, !user.isEmpty {
                infoRow("User", value: user)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Command

    private func commandSection(_ command: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Command", systemImage: "terminal")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(command)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(6)
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }
}
