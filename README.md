# Deskmon

> **Desk**top **Mon**itoring — your servers, at a glance.

A native macOS menu bar app for monitoring home servers. No browser tabs, no Grafana, no complexity. Just click the menu bar and see everything.

![Status](https://img.shields.io/badge/status-MVP-green)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-MIT-brightgreen)
![Swift](https://img.shields.io/badge/Swift-6%2B-orange)
![Agent](https://img.shields.io/badge/agent-Go-00ADD8)

| Menu Bar | Dashboard |
|----------|-----------|
| ![Menu Bar](deskmon/Assets.xcassets/deskmon-menubar.png) | ![Dashboard](deskmon/Assets.xcassets/deskmon-dashboard.png) |

---

## What It Does

Install a lightweight agent on your server, point the macOS app at it, and you get live stats in your menu bar. That's it.

- **System stats** — CPU, memory, disk, network speed with live sparkline graph
- **Docker containers** — status, CPU, memory, network I/O, disk I/O per container
- **Container actions** — start, stop, restart containers from your Mac
- **Process management** — top processes by memory usage, kill by PID
- **Service dashboards** — Pi-hole with full stats and controls; Traefik and Nginx (experimental, untested)
- **Service bookmarks** — quick-launch for any self-hosted service (n8n, Homarr, Dokploy, etc.)
- **Multi-server** — monitor multiple machines from one app
- **Live streaming** — SSE connection with 1s system / 5s Docker / 10s services refresh

---

## Architecture

No cloud. No accounts. No telemetry. The app talks directly to your agent over your local network.

```
┌──────────────────────────────────────────┐
│              Your Mac                     │
│                                          │
│   Deskmon (SwiftUI menu bar app)         │
│   - Streams live stats via SSE           │
│   - Renders native UI                    │
│   - Stores config in UserDefaults        │
│                                          │
└──────────────────┬───────────────────────┘
                   │ HTTP/SSE over LAN
                   ▼
┌──────────────────────────────────────────┐
│            Your Server(s)                 │
│                                          │
│   deskmon-agent (Go binary)              │
│   - Collects system stats (gopsutil)     │
│   - Queries Docker API                   │
│   - Auto-detects services                │
│   - Serves JSON on port 7654            │
│                                          │
└──────────────────────────────────────────┘
```

---

## Installation

### 1. Install the agent on your server

**Docker (recommended for unRAID / TrueNAS):**

Open a terminal on your server (unRAID: click the `>_` icon in the top-right of the web UI), then paste this entire command and press Enter:

```bash
docker run -d \
  --name deskmon-agent \
  --pid=host \
  --network=host \
  -v /:/hostfs:ro,rslave \
  -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/deskmon:/etc/deskmon \
  -e DESKMON_HOST_ROOT=/hostfs \
  -e DESKMON_HOST_SYS=/host/sys \
  --restart unless-stopped \
  ghcr.io/neur0map/deskmon-agent:latest
```

That's it. The agent will start automatically and survive reboots. Your host filesystem is mounted read-only — the agent cannot modify your files or array.

**Prebuilt binary (Ubuntu, Debian, Fedora, etc.):**

```bash
curl -fsSL https://raw.githubusercontent.com/neur0map/deskmon-agent/main/scripts/install-remote.sh | sudo bash
```

**Build from source (requires Go 1.22+):**

```bash
git clone https://github.com/neur0map/deskmon-agent.git
cd deskmon-agent
sudo make setup
```

The agent listens on `127.0.0.1:7654` (localhost only). See the [agent repo](https://github.com/neur0map/deskmon-agent) for configuration, troubleshooting, and what each Docker flag does.

### 2. Install the macOS app

**Option A: Download the DMG** (recommended)

Go to the [Actions tab](https://github.com/neur0map/deskmon/actions) on GitHub, click the latest successful build, and download the **Deskmon.dmg** artifact. Open it and drag Deskmon to your Applications folder.

> **Gatekeeper warning:** Since the build is unsigned, macOS will block it the first time. Right-click the app > Open > Open to bypass. This only happens once.

**Option B: Build from source**

```bash
git clone https://github.com/neur0map/deskmon.git
cd deskmon
open deskmon.xcodeproj
```

Change the signing team to your Apple ID, then build and run (Cmd+R). Requires Xcode 16+.

### 3. Add your server

1. Click the Deskmon icon in your Mac's menu bar
2. Go to **Settings** > **+ Add Server**
3. Enter your server's IP address (e.g. `192.168.1.100`) — this is the same IP you use to access your server's web UI
4. Enter your SSH username and password (unRAID: username is `root`, password is the one you set during setup)
5. Green dot = connected and receiving data

---

## Features

### System Overview

Live CPU, memory, and disk usage with smooth animated bars. Network speed displayed as a 60-second scrolling sparkline graph with Catmull-Rom interpolation.

### Docker Containers

Card-style container list with color-coded status strips. Per-container CPU, memory, network I/O, and disk I/O. Start, stop, and restart containers directly from the app. Running containers sorted first, stopped containers dimmed.

### Service Dashboards

Auto-detected service integrations with dedicated dashboards:

| Service | Stats | Controls | Status |
|---------|-------|----------|--------|
| **Pi-hole** | Queries, blocked %, forwarded, cached, unique domains, clients | Enable/disable blocking | Stable |
| **Traefik** | HTTP/TCP/UDP routers, services, middleware, warnings | — | Experimental |
| **Nginx** | Active connections, requests/sec, reading/writing/waiting | — | Experimental |

Custom URL overrides let you open any service in your browser. Bookmark cards let you add quick links to services the agent doesn't detect (n8n, Homarr, Dokploy, Portainer, etc.).

### Process Management

Top processes sorted by memory usage with stabilization to prevent flickering. Color-tinted resource values (green → orange → red). Kill processes by PID.

---

## Tech Stack

### macOS App

| | |
|---|---|
| **Language** | Swift 6+ with strict concurrency |
| **UI** | Pure SwiftUI |
| **State** | @Observable with @MainActor isolation |
| **Networking** | URLSession async/await, SSE streaming |
| **Persistence** | UserDefaults |
| **Target** | macOS 15+ (Sequoia) |

### Agent

| | |
|---|---|
| **Language** | Go |
| **System stats** | gopsutil |
| **Docker** | Docker SDK via socket |
| **Services** | Auto-detection with plugin collectors |
| **Server** | net/http with SSE streaming |
| **Config** | YAML |
| **Distribution** | Static binary (amd64, arm64) |

---

## Repository Structure

```
deskmon/
├── deskmon/
│   ├── deskmonApp.swift              # App entry: MenuBarExtra + Window
│   ├── Models/
│   │   ├── ServerInfo.swift          # Server connection + stats + network history
│   │   ├── ServerStats.swift         # CPU, memory, disk, network (Codable)
│   │   ├── ServerStatus.swift        # healthy/warning/critical/offline
│   │   ├── DockerContainer.swift     # Container model with full stats
│   │   ├── ProcessInfo.swift         # Process model (PID, CPU, memory)
│   │   ├── ServiceInfo.swift         # Auto-detected services + custom URLs
│   │   └── BookmarkService.swift     # User-created service bookmarks
│   ├── Services/
│   │   ├── ServerManager.swift       # @Observable: SSE streaming, state, CRUD
│   │   └── AgentClient.swift         # HTTP + SSE client with auth
│   ├── Views/
│   │   ├── DashboardView.swift       # Menu bar popover (380x600)
│   │   ├── MainDashboardView.swift   # Full window (sidebar + detail)
│   │   ├── MenuBarLabel.swift        # Dynamic status icon
│   │   ├── Components/               # SystemMetricsCard, NetworkStats, etc.
│   │   ├── Services/                 # Pi-hole, Traefik, Nginx dashboards
│   │   └── Settings/                 # Server add/edit sheets
│   └── Helpers/
│       ├── Theme.swift               # OLED dark palette, card styles
│       └── ByteFormatter.swift       # Human-readable bytes/speeds
├── docs/
│   └── agent-api-contract.md         # SSE event schemas
└── README.md
```

Agent source: [github.com/neur0map/deskmon-agent](https://github.com/neur0map/deskmon-agent)

---

## Agent API

The app connects via SSE at `GET /stats/stream` with Bearer token auth. Events arrive at different intervals:

| Event | Interval | Data |
|-------|----------|------|
| `system` | 1s | CPU, memory, disk, network, uptime, temps |
| `docker` | 5s | All containers with per-container stats |
| `services` | 10s | Detected services with integration stats |
| `processes` | 1s | Top processes by CPU |

See [`docs/agent-api-contract.md`](docs/agent-api-contract.md) for full schemas.

---

## Roadmap

### Done

- [x] Live SSE streaming with auto-reconnect and fallback polling
- [x] System stats (CPU, memory, disk, network sparkline)
- [x] Docker container stats with start/stop/restart actions
- [x] Container detail panel (CPU, memory, network I/O, disk I/O, ports, health)
- [x] Process list with kill support
- [x] Pi-hole dashboard (v5 + v6) with enable/disable blocking
- [x] Traefik dashboard (routers, services, middleware)
- [x] Nginx dashboard (connections, requests)
- [x] Service auto-detection and custom URL overrides
- [x] Service bookmarks for undetected services
- [x] Multi-server support with server switching
- [x] Menu bar icon with dynamic status color
- [x] Full window dashboard with sidebar
- [x] OLED dark theme

### Next

- [ ] More service integrations (Plex, Jellyfin, Home Assistant, AdGuard)
- [ ] Desktop widgets (WidgetKit)
- [ ] Alert thresholds and notifications
- [ ] Historical sparklines (last hour)
- [ ] Keyboard shortcuts

### Future

- [ ] Signed and notarized DMG (Apple Developer subscription — no Gatekeeper warnings)
- [ ] Notifications and alerts (CPU/memory/disk thresholds, container down, service offline)
- [ ] UI/UX improvements
- [ ] iOS companion app
- [ ] Proxmox / TrueNAS integration
- [ ] SMART disk health monitoring
- [ ] GPU stats (Nvidia)
- [ ] Tailscale auto-detection for remote access

---

## Comparison

| Feature | Deskmon | iStatMenus | Beszel | Grafana+Prometheus |
|---------|---------|------------|--------|--------------------|
| Remote server monitoring | Yes | No | Yes | Yes |
| Native macOS menu bar | Yes | Yes | No | No |
| No separate backend needed | Yes | Yes | Yes | No |
| Docker container stats | Yes | No | Yes | Yes |
| Service integrations | Yes | No | No | Via plugins |
| Container actions | Yes | No | No | No |
| Open source | Yes | No | Yes | Yes |
| Zero config | Yes | Yes | Partial | No |

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

### Development Setup

1. Clone the repo
2. Open `deskmon.xcodeproj` in Xcode 16+
3. Change signing team to your Apple ID
4. Build and run (Cmd+R)

The app expects a running [deskmon-agent](https://github.com/neur0map/deskmon-agent) instance to connect to.

---

## License

MIT — see [LICENSE](LICENSE).

Both the macOS app and the [agent](https://github.com/neur0map/deskmon-agent) are open source.

---

*Built for homelab enthusiasts who just want to know their server is okay.*
