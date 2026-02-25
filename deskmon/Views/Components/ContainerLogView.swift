import SwiftUI

struct ContainerLogView: View {
    let container: DockerContainer

    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    @State private var logs = ""
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var autoRefresh = true
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(container.status.color)
                    .frame(width: 8, height: 8)

                Text(container.name)
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    autoRefresh.toggle()
                } label: {
                    Label(autoRefresh ? "Pause" : "Resume", systemImage: autoRefresh ? "pause.fill" : "play.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.dark)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.cardBackground)
            .overlay(alignment: .bottom) {
                Divider().background(Theme.cardBorder)
            }

            // Log content
            if let error = loadError, logs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.warning)
                    Text("Failed to load logs")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(logs.isEmpty ? "Loading…" : logs)
                                .font(.caption.monospaced())
                                .foregroundStyle(logs.isEmpty ? Color.secondary : Color.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)

                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .background(Color.black)
                    .onChange(of: logs) {
                        if autoRefresh {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 720, minHeight: 400, idealHeight: 560)
        .preferredColorScheme(.dark)
        .task { startRefreshLoop() }
        .onChange(of: autoRefresh) {
            if autoRefresh {
                startRefreshLoop()
            } else {
                refreshTask?.cancel()
                refreshTask = nil
            }
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }

    // MARK: - Refresh Loop

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled && autoRefresh {
                await fetchLogs()
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func fetchLogs() async {
        isLoading = true
        do {
            let output = try await serverManager.executeCommand(
                "docker logs --tail 100 \(container.id) 2>&1"
            )
            loadError = nil
            logs = output
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}
