import SwiftUI

// MARK: - Data Model

private struct SecurityData {
    var firewallStatus: String?
    var unattendedUpgrades: String?
    var fail2banOutput: String?
    var pendingSecurityUpdates: Int?
    var failedLogins: [String] = []
    var sshPasswordAuth: String?
    var sshRootLogin: String?
    var appArmorStatus: String?
}

// MARK: - Main View

struct SecurityPanelView: View {
    let serverID: UUID

    @Environment(ServerManager.self) private var serverManager
    @State private var data = SecurityData()
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Security")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await fetchData() }
                } label: {
                    Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.rotate, isActive: isLoading)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                SecurityRowView(
                    label: "Firewall (UFW)",
                    value: firewallLabel,
                    color: firewallColor,
                    info: .init(
                        description: "Controls inbound/outbound network traffic. An inactive firewall exposes all ports to the internet.",
                        fixCommand: firewallFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "Unattended Upgrades",
                    value: upgradesLabel,
                    color: upgradesColor,
                    info: .init(
                        description: "Automatically installs security patches without manual intervention, keeping the system protected against known CVEs.",
                        fixCommand: upgradesFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "Fail2Ban",
                    value: fail2banLabel,
                    color: fail2banColor,
                    info: .init(
                        description: "Monitors log files and automatically bans IPs with repeated failed login attempts, protecting against brute-force attacks.",
                        fixCommand: fail2banFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "Security Updates",
                    value: updatesLabel,
                    color: updatesColor,
                    info: .init(
                        description: "Packages with outstanding CVE security patches available. Apply promptly to reduce exposure to known vulnerabilities.",
                        fixCommand: updatesFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "SSH Password Auth",
                    value: sshPasswordAuthLabel,
                    color: sshPasswordAuthColor,
                    info: .init(
                        description: "Password-based SSH authentication is vulnerable to brute-force attacks. Key-based authentication is strongly recommended.",
                        fixCommand: sshPasswordAuthFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "SSH Root Login",
                    value: sshRootLoginLabel,
                    color: sshRootLoginColor,
                    info: .init(
                        description: "Allowing direct root SSH login bypasses audit trails and increases attack surface. Use a regular user with sudo instead.",
                        fixCommand: sshRootLoginFixCommand
                    )
                )

                Divider().background(Theme.cardBorder)

                SecurityRowView(
                    label: "AppArmor",
                    value: appArmorLabel,
                    color: appArmorColor,
                    info: .init(
                        description: "Mandatory access control system that confines programs to a limited set of resources, limiting damage from compromised processes.",
                        fixCommand: appArmorFixCommand
                    )
                )

                if !data.failedLogins.isEmpty {
                    Divider().background(Theme.cardBorder)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Recent Failed SSH Logins")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            InfoButton(info: .init(
                                description: "A high volume of failed logins may indicate a brute-force attack in progress. Fail2Ban can automatically block repeat offenders.",
                                fixCommand: nil
                            ))
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(data.failedLogins, id: \.self) { line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .cardStyle(cornerRadius: 10)
        }
        .task { await fetchData() }
    }

    // MARK: - Labels & Colors

    private var firewallLabel: String {
        guard let s = data.firewallStatus else { return "N/A" }
        return s.localizedCaseInsensitiveContains("active") ? "Active" : "Inactive"
    }
    private var firewallColor: Color {
        guard let s = data.firewallStatus else { return .secondary }
        return s.localizedCaseInsensitiveContains("active") ? Theme.healthy : Theme.warning
    }
    private var firewallFixCommand: String? {
        guard let s = data.firewallStatus, s.localizedCaseInsensitiveContains("active") else {
            return "sudo ufw allow ssh && sudo ufw enable"
        }
        return nil
    }

    private var upgradesLabel: String {
        guard let s = data.unattendedUpgrades else { return "N/A" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
    private var upgradesColor: Color {
        guard let s = data.unattendedUpgrades else { return .secondary }
        return s.localizedCaseInsensitiveContains("enabled") ? Theme.healthy : Theme.warning
    }
    private var upgradesFixCommand: String? {
        guard let s = data.unattendedUpgrades, s.localizedCaseInsensitiveContains("enabled") else {
            return "sudo apt install unattended-upgrades -y && sudo dpkg-reconfigure -plow unattended-upgrades"
        }
        return nil
    }

    private var fail2banLabel: String {
        guard let s = data.fail2banOutput else { return "N/A" }
        if s.localizedCaseInsensitiveContains("Number of jails"),
           let range = s.range(of: #"Number of jails:\s*(\d+)"#, options: .regularExpression),
           let numRange = s[range].range(of: #"\d+"#, options: .regularExpression) {
            let count = String(s[range][numRange])
            return "\(count) jail\(count == "1" ? "" : "s")"
        }
        return s.localizedCaseInsensitiveContains("fail2ban") ? "Active" : "N/A"
    }
    private var fail2banColor: Color {
        guard let s = data.fail2banOutput else { return .secondary }
        return s.localizedCaseInsensitiveContains("jail") || s.localizedCaseInsensitiveContains("fail2ban") ? Theme.healthy : Theme.warning
    }
    private var fail2banFixCommand: String? {
        guard let s = data.fail2banOutput,
              s.localizedCaseInsensitiveContains("jail") || s.localizedCaseInsensitiveContains("fail2ban") else {
            return "sudo apt install fail2ban -y && sudo systemctl enable --now fail2ban"
        }
        return nil
    }

    private var updatesLabel: String {
        guard let n = data.pendingSecurityUpdates else { return "N/A" }
        return n == 0 ? "Up to date" : "\(n) pending"
    }
    private var updatesColor: Color {
        guard let n = data.pendingSecurityUpdates else { return .secondary }
        if n == 0 { return Theme.healthy }
        if n <= 5 { return Theme.warning }
        return Theme.critical
    }
    private var updatesFixCommand: String? {
        guard let n = data.pendingSecurityUpdates, n > 0 else { return nil }
        return "sudo apt-get upgrade -y"
    }

    private var sshPasswordAuthLabel: String {
        guard let s = data.sshPasswordAuth, !s.isEmpty else { return "N/A" }
        if s.localizedCaseInsensitiveContains("no") { return "Disabled" }
        if s.localizedCaseInsensitiveContains("yes") { return "Enabled" }
        return "N/A"
    }
    private var sshPasswordAuthColor: Color {
        guard let s = data.sshPasswordAuth, !s.isEmpty else { return .secondary }
        if s.localizedCaseInsensitiveContains("no") { return Theme.healthy }
        if s.localizedCaseInsensitiveContains("yes") { return Theme.critical }
        return .secondary
    }
    private var sshPasswordAuthFixCommand: String? {
        guard let s = data.sshPasswordAuth, s.localizedCaseInsensitiveContains("yes") else { return nil }
        return "sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl reload sshd"
    }

    private var sshRootLoginLabel: String {
        guard let s = data.sshRootLogin, !s.isEmpty else { return "N/A" }
        if s.localizedCaseInsensitiveContains("prohibit-password") { return "Key-only" }
        if s.localizedCaseInsensitiveContains("no") { return "Disabled" }
        if s.localizedCaseInsensitiveContains("yes") { return "Enabled" }
        return "N/A"
    }
    private var sshRootLoginColor: Color {
        guard let s = data.sshRootLogin, !s.isEmpty else { return .secondary }
        if s.localizedCaseInsensitiveContains("prohibit-password") { return Theme.warning }
        if s.localizedCaseInsensitiveContains("no") { return Theme.healthy }
        if s.localizedCaseInsensitiveContains("yes") { return Theme.critical }
        return .secondary
    }
    private var sshRootLoginFixCommand: String? {
        guard let s = data.sshRootLogin, s.localizedCaseInsensitiveContains("yes") else { return nil }
        return "sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && sudo systemctl reload sshd"
    }

    private var appArmorLabel: String {
        guard let s = data.appArmorStatus, !s.isEmpty else { return "N/A" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
    private var appArmorColor: Color {
        guard let s = data.appArmorStatus, !s.isEmpty else { return .secondary }
        return s.localizedCaseInsensitiveContains("active") ? Theme.healthy : Theme.warning
    }
    private var appArmorFixCommand: String? {
        guard let s = data.appArmorStatus, s.localizedCaseInsensitiveContains("active") else {
            return "sudo apt install apparmor -y && sudo systemctl enable --now apparmor"
        }
        return nil
    }

    // MARK: - Fetch

    private func fetchData() async {
        isLoading = true
        defer { isLoading = false }

        async let firewall = try? await serverManager.executeCommand(
            "ufw status 2>/dev/null | head -1", on: serverID
        )
        async let upgrades = try? await serverManager.executeCommand(
            "systemctl is-enabled unattended-upgrades 2>/dev/null", on: serverID
        )
        async let fail2ban = try? await serverManager.executeCommand(
            "fail2ban-client status 2>/dev/null | head -4", on: serverID
        )
        async let secUpdates = try? await serverManager.executeCommand(
            "apt list --upgradable 2>/dev/null | grep -ic security; true", on: serverID
        )
        async let logins = try? await serverManager.executeCommand(
            #"journalctl _SYSTEMD_UNIT=sshd.service --no-pager -n 50 2>/dev/null | grep "Failed" | tail -5"#,
            on: serverID
        )
        async let sshPasswordAuth = try? await serverManager.executeCommand(
            "grep -E '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'",
            on: serverID
        )
        async let sshRootLogin = try? await serverManager.executeCommand(
            "grep -E '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'",
            on: serverID
        )
        async let appArmor = try? await serverManager.executeCommand(
            "systemctl is-active apparmor 2>/dev/null", on: serverID
        )

        let (fw, ug, f2b, upd, lg, spa, srl, aa) = await (
            firewall, upgrades, fail2ban, secUpdates, logins, sshPasswordAuth, sshRootLogin, appArmor
        )

        data.firewallStatus        = fw?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.unattendedUpgrades    = ug?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.fail2banOutput        = f2b?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.pendingSecurityUpdates = upd.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        data.failedLogins = lg?
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        data.sshPasswordAuth = spa?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.sshRootLogin    = srl?.trimmingCharacters(in: .whitespacesAndNewlines)
        data.appArmorStatus  = aa?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Row View

private struct SecurityRowView: View {
    struct Info {
        let description: String
        let fixCommand: String?
    }

    let label: String
    let value: String
    let color: Color
    let info: Info

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
            InfoButton(info: info)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Info Button

private struct InfoButton: View {
    let info: SecurityRowView.Info
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            InfoPopoverContent(info: info)
        }
    }
}

// MARK: - Popover Content

private struct InfoPopoverContent: View {
    let info: SecurityRowView.Info
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(info.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let cmd = info.fixCommand {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested Fix")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        Text(cmd)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cmd, forType: .string)
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(copied ? Theme.healthy : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.cardBorder, lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .preferredColorScheme(.dark)
    }
}
