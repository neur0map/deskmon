import Citadel
import Crypto
import Foundation
import NIO
import NIOSSH
import os

/// Manages a single SSH connection and a local TCP-to-SSH tunnel.
///
/// The tunnel works by binding a local NIO TCP server on 127.0.0.1.
/// When URLSession connects to this local port, each TCP connection
/// opens a directTCPIP channel through SSH and bridges bytes bidirectionally.
/// This keeps all existing AgentClient HTTP/SSE code unchanged.
@Observable
final class SSHManager {

    // MARK: - Observable State

    private(set) var phase: SSHPhase = .disconnected
    private(set) var tunnelPort: Int = 0

    // MARK: - Private

    private var sshClient: SSHClient?
    private var localServer: Channel?
    private var extraTunnels: [Int: (channel: Channel, localPort: Int)] = [:]
    private let group = MultiThreadedEventLoopGroup.singleton
    private var disconnectCallbacks: [@Sendable () -> Void] = []

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "SSHManager")

    enum SSHPhase: Sendable {
        case disconnected
        case connecting
        case connected       // SSH up, no tunnel yet
        case tunnelOpen      // Local listener active
    }

    /// Base URL for AgentClient to use (points at the local tunnel).
    var tunnelBaseURL: String? {
        guard tunnelPort > 0, phase == .tunnelOpen else { return nil }
        return "http://127.0.0.1:\(tunnelPort)"
    }

    var isConnected: Bool {
        sshClient?.isConnected ?? false
    }

    // MARK: - Connect

    /// Connect via SSH password authentication.
    func connect(host: String, port: Int = 22, username: String, password: String) async throws {
        phase = .connecting
        Self.log.info("SSH connecting to \(username)@\(host):\(port) (password)")

        do {
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            sshClient = client
            phase = .connected
            Self.log.info("SSH connected to \(host):\(port)")
            wireDisconnectHandler()
        } catch {
            phase = .disconnected
            Self.log.error("SSH connect failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Connect via SSH ed25519 key authentication.
    func connect(host: String, port: Int = 22, username: String, privateKey: Curve25519.Signing.PrivateKey) async throws {
        phase = .connecting
        Self.log.info("SSH connecting to \(username)@\(host):\(port) (key)")

        do {
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .ed25519(username: username, privateKey: privateKey),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            sshClient = client
            phase = .connected
            Self.log.info("SSH connected to \(host):\(port)")
            wireDisconnectHandler()
        } catch {
            phase = .disconnected
            Self.log.error("SSH key connect failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Tunnel

    /// Start a local TCP listener that bridges connections through SSH to the remote agent.
    func openTunnel(remoteHost: String = "127.0.0.1", remotePort: Int = 7654) async throws {
        guard let client = sshClient, client.isConnected else {
            throw SSHTunnelError.notConnected
        }

        // Close any existing tunnel
        closeTunnel()

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 8)
            .childChannelOption(.allowRemoteHalfClosure, value: true)
            .childChannelInitializer { [client] localChannel in
                let handler = TunnelBridgeHandler(
                    sshClient: client,
                    remoteHost: remoteHost,
                    remotePort: remotePort
                )
                return localChannel.pipeline.addHandler(handler)
            }

        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()

        guard let port = serverChannel.localAddress?.port else {
            try await serverChannel.close()
            throw SSHTunnelError.bindFailed
        }

        localServer = serverChannel
        tunnelPort = port
        phase = .tunnelOpen
        Self.log.info("Tunnel open on 127.0.0.1:\(port) → \(remoteHost):\(remotePort)")
    }

    // MARK: - Extra Tunnels (for plugins)

    /// Open (or reuse) an additional SSH tunnel to `remotePort` on the remote host.
    /// Returns the local base URL, e.g. `"http://127.0.0.1:54321"`.
    func openExtraTunnel(remotePort: Int) async throws -> String {
        if let existing = extraTunnels[remotePort] {
            return "http://127.0.0.1:\(existing.localPort)"
        }

        guard let client = sshClient, client.isConnected else {
            throw SSHTunnelError.notConnected
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 8)
            .childChannelOption(.allowRemoteHalfClosure, value: true)
            .childChannelInitializer { [client] localChannel in
                let handler = TunnelBridgeHandler(
                    sshClient: client,
                    remoteHost: "127.0.0.1",
                    remotePort: remotePort
                )
                return localChannel.pipeline.addHandler(handler)
            }

        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()

        guard let port = serverChannel.localAddress?.port else {
            try await serverChannel.close().get()
            throw SSHTunnelError.bindFailed
        }

        extraTunnels[remotePort] = (channel: serverChannel, localPort: port)
        Self.log.info("Extra tunnel open on 127.0.0.1:\(port) → 127.0.0.1:\(remotePort)")
        return "http://127.0.0.1:\(port)"
    }

    // MARK: - Disconnect

    func disconnect() {
        closeTunnel()
        closeExtraTunnels()

        if let client = sshClient {
            Task.detached { [client] in
                try? await client.close()
            }
        }
        sshClient = nil
        phase = .disconnected
        Self.log.info("SSH disconnected")
    }

    /// Register a callback for when the SSH connection drops unexpectedly.
    func onDisconnect(_ callback: @escaping @Sendable () -> Void) {
        disconnectCallbacks.append(callback)
    }

    /// Execute a command on the remote server (used for key installation).
    func executeCommand(_ command: String) async throws -> String {
        guard let client = sshClient, client.isConnected else {
            throw SSHTunnelError.notConnected
        }
        let buffer = try await client.executeCommand(command)
        return String(buffer: buffer)
    }

    // MARK: - Private

    private func closeTunnel() {
        if let server = localServer {
            try? server.close().wait()
            localServer = nil
        }
        tunnelPort = 0
        if phase == .tunnelOpen {
            phase = sshClient?.isConnected == true ? .connected : .disconnected
        }
    }

    private func closeExtraTunnels() {
        for (_, tunnel) in extraTunnels {
            try? tunnel.channel.close().wait()
        }
        extraTunnels.removeAll()
    }

    private func wireDisconnectHandler() {
        sshClient?.onDisconnect { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                Self.log.warning("SSH connection dropped")
                self.localServer = nil
                self.tunnelPort = 0
                self.extraTunnels.removeAll()
                self.sshClient = nil
                self.phase = .disconnected
                for callback in self.disconnectCallbacks {
                    callback()
                }
            }
        }
    }
}

// MARK: - Errors

enum SSHTunnelError: LocalizedError {
    case notConnected
    case bindFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: "SSH not connected"
        case .bindFailed: "Failed to bind local tunnel port"
        }
    }
}

// MARK: - NIO Tunnel Bridge

/// Bridges a local TCP connection to a remote host through an SSH directTCPIP channel.
/// One instance per accepted local connection.
private final class TunnelBridgeHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let sshClient: SSHClient
    private let remoteHost: String
    private let remotePort: Int
    private var sshChannel: Channel?
    private var pendingWrites: [ByteBuffer] = []
    private var localChannel: Channel?

    init(sshClient: SSHClient, remoteHost: String, remotePort: Int) {
        self.sshClient = sshClient
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    func channelActive(context: ChannelHandlerContext) {
        localChannel = context.channel

        let localChan = context.channel
        let host = remoteHost
        let port = remotePort

        Task {
            do {
                let sshChan = try await sshClient.createDirectTCPIPChannel(
                    using: .init(
                        targetHost: host,
                        targetPort: port,
                        originatorAddress: try .init(ipAddress: "127.0.0.1", port: 0)
                    )
                ) { channel in
                    channel.pipeline.addHandler(ReverseBridgeHandler(peerChannel: localChan))
                }
                self.sshChannel = sshChan

                // Flush any data received before the SSH channel was ready
                for buffer in self.pendingWrites {
                    sshChan.writeAndFlush(NIOAny(buffer), promise: nil)
                }
                self.pendingWrites.removeAll()
            } catch {
                localChan.close(promise: nil)
            }
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        if let sshChan = sshChannel {
            sshChan.writeAndFlush(NIOAny(buffer), promise: nil)
        } else {
            // SSH channel not ready yet, buffer the data
            pendingWrites.append(buffer)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        sshChannel?.close(promise: nil)
        sshChannel = nil
        pendingWrites.removeAll()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}

/// Reverse direction handler: reads from SSH channel and writes to the local TCP socket.
private final class ReverseBridgeHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let peerChannel: Channel

    init(peerChannel: Channel) {
        self.peerChannel = peerChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        peerChannel.writeAndFlush(NIOAny(buffer), promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        peerChannel.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
