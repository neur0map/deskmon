import SwiftUI
import UniformTypeIdentifiers

struct AddServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var useKeyAuth = false
    @State private var keyFileData: Data?
    @State private var keyFileName = ""
    @State private var passphrase = ""
    @State private var showFilePicker = false

    @State private var isConnecting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let fieldsOK = !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !host.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !username.trimmingCharacters(in: .whitespaces).isEmpty
        return fieldsOK && (useKeyAuth ? keyFileData != nil : !password.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Server")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                field("Name", text: $name, prompt: "Homelab")
                field("Host / IP", text: $host, prompt: "192.168.1.100")
                field("SSH Username", text: $username, prompt: "root")

                // Auth method selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authentication")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $useKeyAuth) {
                        Text("Password").tag(false)
                        Text("SSH Key").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if useKeyAuth {
                    keyFilePicker
                } else {
                    secureField("SSH Password", text: $password, prompt: "Password")
                }
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.critical)
                    Text(errorMessage)
                        .foregroundStyle(Theme.critical)
                }
                .font(.caption)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await connectAndAdd() }
                } label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Connect")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isConnecting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 380)
        .frame(minHeight: 340)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                keyFileData = data
                keyFileName = url.lastPathComponent
            }
        }
    }

    private var keyFilePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Private Key File")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(keyFileName.isEmpty ? "No file selected" : keyFileName)
                        .foregroundStyle(keyFileName.isEmpty ? .quaternary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 5))
                    Button("Choose…") { showFilePicker = true }
                        .fixedSize()
                }
            }
            secureField("Passphrase", text: $passphrase, prompt: "Leave empty if none")
        }
    }

    private func connectAndAdd() async {
        errorMessage = nil
        isConnecting = true
        defer { isConnecting = false }

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        let server = serverManager.addServer(
            name: trimmedName,
            host: trimmedHost,
            username: trimmedUsername
        )

        do {
            if useKeyAuth, let data = keyFileData {
                try await serverManager.connectServer(server, keyData: data, passphrase: passphrase.isEmpty ? nil : passphrase)
            } else {
                try await serverManager.connectServer(server, password: password)
            }
            dismiss()
        } catch {
            serverManager.deleteServer(server)
            errorMessage = Self.friendlyError(error)
        }
    }

    private static func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription
        if msg.contains("IOError") && msg.contains("error 61") {
            return "Connection refused — check host and SSH port"
        }
        if msg.contains("IOError") && msg.contains("error 1") {
            return "Connection not permitted — check network permissions"
        }
        if msg.lowercased().contains("authentication") || msg.lowercased().contains("password") {
            return "Authentication failed — check username and password"
        }
        if msg.contains("IOError") && msg.contains("error 60") {
            return "Connection timed out — host may be unreachable"
        }
        if msg.contains("error 4") {
            return "SSH key not authorized — verify the key is in ~/.ssh/authorized_keys on the server"
        }
        return msg
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.quaternary))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func secureField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.quaternary))
                .textFieldStyle(.roundedBorder)
        }
    }
}
