# Deskmon

> **Desk**top **Mon**itoring — your servers, at a glance.

**Native macOS menu bar app for monitoring your home servers.**

A lightweight, privacy-first server monitoring tool designed for homelab enthusiasts. See your server stats at a glance without opening a browser or setting up complex monitoring stacks.

![Status](https://img.shields.io/badge/status-in%20development-yellow)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-proprietary-red)

---

## Vision

**The problem:** You run a home server (pihole, file storage, Plex, docker containers). Checking on it means SSH-ing in, opening a browser to various dashboards, or setting up heavyweight solutions like Grafana + Prometheus.

**The solution:** A native macOS menu bar app that shows you everything at a glance. One click. No browser. No complexity.

---

## Target Audience

- **Homelab enthusiasts** running personal servers
- **Developers** with local dev servers or VMs
- **Self-hosters** running pihole, Plex, Jellyfin, Home Assistant
- **Mac users** who want native UX, not Electron bloat
- **Privacy-conscious** users who don't want cloud monitoring

### User Persona

> "I run a Linux server at home with pihole, some docker containers, and file storage. I use my Mac for everything else. I just want to glance up at my menu bar and know my server is healthy without context-switching."

---

## Core Features

### Menu Bar App (macOS)

- **Status at a glance**: Green/yellow/red indicator in menu bar
- **Quick dropdown**: Click to see live stats
- **Multi-server support**: Monitor multiple machines
- **Native Swift/SwiftUI**: Fast, lightweight, no Electron
- **Widgets**: Desktop and notification center widgets
- **Alerts**: Get notified when thresholds are exceeded

### Agent (Linux/BSD)

- **Tiny footprint**: Single binary, <5MB, minimal CPU usage
- **Zero config**: Works out of the box
- **Open source**: Inspect what runs on your server
- **Secure**: Binds to local network only, optional auth token

---

## Stats & Metrics

### System (Always Available)

| Metric | Description |
|--------|-------------|
| CPU | Usage percentage, per-core breakdown |
| Memory | Used/total RAM, swap usage |
| Disk | Usage per mount, read/write speeds |
| Network | Upload/download speeds, total transferred |
| Load | 1/5/15 minute load averages |
| Uptime | How long the server has been running |
| Temperature | CPU/GPU temps (where available) |

### Docker Containers

| Metric | Description |
|--------|-------------|
| Status | Running, stopped, restarting |
| CPU | Per-container CPU usage |
| Memory | Usage, limit, percentage |
| Network | RX/TX bytes (cumulative) |
| Disk I/O | Read/write bytes (cumulative) |
| PIDs | Process count |
| Uptime | Time since container start |

<!-- TODO: Ports (exposed port mappings), health check status, restart count -->

### App Integrations (Planned)

| App | Metrics |
|-----|---------|
| **Pihole** | Queries today, blocked %, top domains |
| **Plex** | Active streams, library stats |
| **Jellyfin** | Active streams, users |
| **Home Assistant** | Entity count, automations |
| **AdGuard Home** | Similar to Pihole |
| **Portainer** | Stacks, containers |
| **Proxmox** | VMs, resource usage |
| **TrueNAS** | Pools, disk health |

---

## Design Philosophy

### Native First
Built with Swift and SwiftUI. Feels like a first-party Apple app. Follows macOS design conventions. Plays nice with system dark mode, accent colors, and accessibility features.

### Privacy First
- All data stays on your network
- No cloud, no accounts, no telemetry
- Agent source code is open for inspection
- Works completely offline

### Simplicity First
- Zero configuration for basic usage
- Install agent → add server IP → done
- Power features available but not required

---

## Pricing Model

### Free Tier
- 1 server
- Core system stats
- 60-second refresh interval

### Pro ($5/month or $80 lifetime)
- Unlimited servers
- Docker container stats
- App integrations (Pihole, Plex, etc.)
- 5-second refresh interval
- Desktop widgets
- Custom alerts
- Priority support

---

## Architecture

Deskmon uses a simple client-agent architecture. There is no intermediate backend or cloud service.

```
┌─────────────────────────────────────────────────────────┐
│                     Your Mac                            │
│  ┌───────────────────────────────────────────────────┐ │
│  │            macOS Menu Bar App                     │ │
│  │              (Pure SwiftUI)                       │ │
│  │                                                   │ │
│  │  - Stores server list (UserDefaults/SwiftData)   │ │
│  │  - Polls each agent via HTTP                     │ │
│  │  - Renders stats in native UI                    │ │
│  │  - No local backend process needed               │ │
│  └───────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP/JSON over LAN
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   Your Server(s)                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │              deskmon-agent (Go)                   │ │
│  │                                                   │ │
│  │  - Collects system stats (CPU, RAM, disk, net)   │ │
│  │  - Queries Docker API for container stats        │ │
│  │  - Queries app APIs (Pihole, Plex, etc.)         │ │
│  │  - Serves JSON on port 7654                      │ │
│  │  - THIS IS THE BACKEND                           │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Key Points

- **The agent IS the backend.** It runs on your server, collects data, and serves it via HTTP.
- **The macOS app is a pure client.** It's 100% SwiftUI with no embedded backend or local server process.
- **No cloud, no relay.** The app talks directly to your agent(s) over your local network.
- **Multiple servers?** The app polls each agent independently.

### Communication Flow

1. Agent runs on server, binds to `0.0.0.0:7654`
2. macOS app stores list of server IPs in local storage
3. App polls each agent every N seconds via HTTP GET
4. App renders the JSON response in SwiftUI
5. Optional: Auth token header for security

<!-- TODO: Hybrid approach — add a WebSocket endpoint (/ws) alongside HTTP polling for:
     - Real-time container log streaming (without polling)
     - Container actions (start/stop/restart) with immediate feedback
     - Push-based alerts (threshold exceeded, container crashed)
     Stats polling continues independently so the app degrades gracefully
     if the WebSocket connection drops. -->

### Agent Endpoints

See [`docs/agent-api-contract.md`](docs/agent-api-contract.md) for the full API contract.

```
GET /health          -> { "status": "ok" }
GET /stats           -> Full system + container stats JSON
```

---

## UI Mockup

```
┌──────────────────────────────────────┐
│ prowl-server               12d  │
├──────────────────────────────────────┤
│                                      │
│  CPU   ████████░░░░░░░░  48%        │
│  RAM   ██████████████░░  87%  14GB  │
│  Disk  ████████░░░░░░░░  52%  240G  │
│  Net   ↓ 12.4 MB/s   ↑ 1.2 MB/s    │
│                                      │
├──────────────────────────────────────┤
│  Containers (6)                   │
│                                      │
│   ● pihole         0.5%     128MB   │
│   ● plex          12.3%     2.1GB   │
│   ● homebridge     0.1%      64MB   │
│   ● jellyfin       2.1%     512MB   │
│   ● homeassistant  1.8%     384MB   │
│   ○ nginx         stopped           │
│                                      │
├──────────────────────────────────────┤
│  Pihole                           │
│   Queries: 45.6k   Blocked: 27.3%   │
│   Status: Enabled                    │
│                                      │
├──────────────────────────────────────┤
│  Settings    Add Server        │
└──────────────────────────────────────┘
```

---

## Roadmap

### Phase 1: MVP (Weeks 1-5)
- [ ] Agent: Core system stats (CPU, RAM, disk, network)
- [ ] Agent: Docker container stats
- [ ] Agent: HTTP server with JSON API
- [ ] Agent: Install script (curl | bash)
- [x] macOS: Menu bar icon with status color
- [x] macOS: Popover with live stats (380x600 menu bar popover)
- [x] macOS: Full window with sidebar + detail panel (Cmd+1)
- [x] macOS: Add/edit/remove servers
- [x] macOS: Settings (polling toggle, refresh interval, restart agent)
- [x] macOS: Docker container detail panel (CPU, memory, network, disk I/O)
- [x] macOS: OLED dark theme with orange accent
- [x] macOS: API contract defined ([docs/agent-api-contract.md](docs/agent-api-contract.md))

### Phase 2: Integrations (Weeks 6-8)
- [ ] Agent: Pihole integration
- [ ] Agent: Plex integration
- [ ] Agent: Config file for integrations
- [ ] macOS: Integration UI
- [ ] macOS: Desktop widgets

### Phase 3: Polish (Weeks 9-10)
- [ ] macOS: Alert thresholds & notifications
- [ ] macOS: Keyboard shortcuts
- [ ] Landing page & docs
- [ ] Payment integration (Gumroad/Paddle)
- [ ] TestFlight beta

### Phase 4: Expansion (Future)
- [ ] More integrations (Jellyfin, Home Assistant, Proxmox)
- [ ] iOS companion app
- [ ] Historical data & graphs
- [ ] Multi-user / family sharing

---

## Tech Stack

### Agent (runs on your server)
- **Language**: Go
- **Purpose**: Collect stats, serve JSON API (this is the backend)
- **Dependencies**: Minimal (stdlib + docker client)
- **Build**: Static binary, cross-compiled for Linux (amd64, arm64)
- **Distribution**: GitHub releases, install script
- **Source**: Open source (MIT) at [deskmon-agent](https://github.com/neur0map/deskmon-agent)

### macOS App (runs on your Mac)
- **Language**: Swift 6+
- **UI**: SwiftUI (pure, no embedded backend)
- **Purpose**: HTTP client + native UI rendering
- **State**: @Observable with @MainActor isolation
- **Networking**: URLSession with async/await (mock data currently)
- **Target**: macOS 26 (Tahoe)
- **Distribution**: Direct download, potentially Mac App Store
- **Source**: Closed source (proprietary)

---

## Repository Structure

```
deskmon/                          # This repo — macOS app
├── deskmon/
│   ├── deskmonApp.swift          # App entry: MenuBarExtra + Window
│   ├── Models/
│   │   ├── ServerInfo.swift      # Server model (name, host, port, token)
│   │   ├── ServerStats.swift     # CPU, memory, disk stats (Codable)
│   │   ├── ServerStatus.swift    # Enum: healthy/warning/critical/offline
│   │   └── DockerContainer.swift # Container model with full stats
│   ├── Services/
│   │   ├── ServerManager.swift   # @Observable: polling, state, CRUD
│   │   └── MockDataProvider.swift # Realistic fluctuating mock data
│   ├── Views/
│   │   ├── DashboardView.swift       # Menu bar popover (380x600)
│   │   ├── MainDashboardView.swift   # Full window (sidebar + detail)
│   │   ├── MenuBarLabel.swift        # Dynamic SF Symbol
│   │   ├── Components/              # Reusable UI components
│   │   └── Settings/                # Add/edit server sheets
│   ├── Helpers/
│   │   ├── Theme.swift           # OLED dark palette, card styles
│   │   └── ByteFormatter.swift   # Human-readable bytes/speeds
│   └── Assets.xcassets/
├── docs/
│   ├── agent-api-contract.md     # What the app expects from the agent
│   └── plans/                    # Design documents
└── README.md

deskmon-agent/                    # Separate repo — Go agent
└── (https://github.com/neur0map/deskmon-agent)
```

---

## Competition & Differentiation

| Feature | Deskmon | iStatMenus | Beszel | Zabbix Monitor |
|---------|-------|------------|--------|----------------|
| Remote servers | ✅ | ❌ | ✅ | ✅ |
| macOS native | ✅ | ✅ | ❌ | ✅ |
| No backend required | ✅ | ✅ | ✅ | ❌ |
| Docker stats | ✅ | ❌ | ✅ | ✅ |
| App integrations | ✅ | ❌ | ❌ | via Zabbix |
| Open source agent | ✅ | N/A | ✅ | N/A |
| Menu bar | ✅ | ✅ | ❌ | ✅ |

---

## License

- **Agent**: MIT (open source)
- **macOS App**: Proprietary (closed source)

---

*Built for homelab enthusiasts who just want to know their server is okay.*
