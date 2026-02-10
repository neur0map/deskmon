import SwiftUI

struct EditServerSheet: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    let server: ServerInfo

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var token: String

    init(server: ServerInfo) {
        self.server = server
        _name = State(initialValue: server.name)
        _host = State(initialValue: server.host)
        _port = State(initialValue: String(server.port))
        _token = State(initialValue: server.token)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != server.name ||
        host != server.host ||
        port != String(server.port) ||
        token != server.token
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Server")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                field("Name", text: $name, prompt: "Homelab")
                field("Host / IP", text: $host, prompt: "192.168.1.100")

                HStack(spacing: 12) {
                    field("Port", text: $port, prompt: "9090")
                        .frame(width: 100)
                    secureField("Token", text: $token, prompt: "Optional")
                }
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let portNum = Int(port) ?? 9090
                    serverManager.updateServer(
                        id: server.id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        host: host.trimmingCharacters(in: .whitespaces),
                        port: portNum,
                        token: token
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || !hasChanges)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 380, height: 290)
        .background(Theme.background)
        .preferredColorScheme(.dark)
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
