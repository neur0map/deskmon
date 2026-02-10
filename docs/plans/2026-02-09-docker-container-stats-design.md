# Docker Container Stats — Design Document

Date: 2026-02-09
Status: Approved

---

## Goal

Add detailed Docker container stats to Deskmon. Users can see per-container resource usage at a glance in the container table, and click any container to open a detail panel showing CPU, memory, network I/O, and disk I/O.

---

## Architecture

### Communication: HTTP Polling

The macOS app polls `GET /stats` from the Go agent every 3 seconds. The agent collects Docker stats via the Docker socket (`/var/run/docker.sock`), computes CPU percentages from cumulative counters between poll cycles, and returns a clean JSON payload. The app just displays pre-computed values.

<!-- TODO: Hybrid approach — keep polling for stats (simple, stateless, curl-debuggable),
     but add a WebSocket endpoint (`/ws`) for future use cases:
     - Real-time log streaming (container logs without polling)
     - Container actions (start/stop/restart with immediate feedback)
     - Push-based alerts (threshold exceeded, container crashed)
     The WebSocket connection would be optional and additive — stats polling
     continues to work independently so the app degrades gracefully. -->

### Agent JSON Contract

The agent's `/stats` response includes a `containers` array:

```json
{
  "system": { "..." },
  "containers": [
    {
      "id": "a1b2c3d4e5f6",
      "name": "pihole",
      "image": "pihole/pihole:latest",
      "status": "running",
      "cpuPercent": 2.4,
      "memoryUsageMB": 142.5,
      "memoryLimitMB": 512.0,
      "networkRxBytes": 1048576000,
      "networkTxBytes": 524288000,
      "blockReadBytes": 2147483648,
      "blockWriteBytes": 1073741824,
      "pids": 12,
      "startedAt": "2025-01-15T08:30:00Z"
    }
  ]
}
```

The agent computes:
- `cpuPercent` — Delta between cumulative CPU usage samples, divided by system delta
- `memoryUsageMB` / `memoryLimitMB` — From Docker stats, converted to MB
- `networkRxBytes` / `networkTxBytes` — Cumulative totals from container start
- `blockReadBytes` / `blockWriteBytes` — Cumulative totals from container start
- `pids` — Current process count inside the container
- `startedAt` — ISO 8601 timestamp, app computes uptime client-side

This contract may change during agent implementation. The Swift models are `Codable` so adjustments are straightforward.

<!-- TODO: Future fields to add to the agent payload:
     - ports: [{"host": 8080, "container": 80, "protocol": "tcp"}]
     - restartCount: int
     - healthStatus: "healthy" | "unhealthy" | "starting" | "none"
     - healthLog: string (last health check output) -->

---

## Swift Model

Expand `DockerContainer` with the new fields:

```swift
struct DockerContainer: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var image: String
    var status: ContainerStatus
    var cpuPercent: Double
    var memoryUsageMB: Double
    var memoryLimitMB: Double
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var blockReadBytes: Int64
    var blockWriteBytes: Int64
    var pids: Int
    var startedAt: Date?

    // TODO: ports — [PortMapping] for exposed port mappings
    // TODO: restartCount — number of times container has restarted
    // TODO: healthStatus — healthy/unhealthy/starting/none
    // TODO: healthLog — last health check output string
}
```

`MockDataProvider.generateContainers()` updated to produce realistic values for all new fields so UI development proceeds without the real agent.

---

## UI Design

### Full Window — Three-Column Master-Detail

The full window (`MainDashboardView`) already has sidebar (servers) | detail (stats + container table). Clicking a container row adds a third column on the right:

```
+----------+-----------------------------+------------------+
| Servers  |  Server Detail              | Container Detail |
|          |                             |                  |
| * Home   |  [status bar]               |  pihole          |
|   Media  |  [CPU] [MEM] [DISK]         |  * Running       |
|          |  [Network]                  |  Up 26d 4h       |
|          |                             |                  |
|          |  Containers (6)             |  CPU    2.4%     |
|          |  +---------------------+    |  Memory 142/512  |
|          |  | * pihole  <- selected    |  PIDs   12       |
|          |  | * plex          |    |                  |
|          |  | * homebridge    |    |  Network         |
|          |  | * jellyfin      |    |  v 1.0 GB total  |
|          |  | * homeassistant |    |  ^ 500 MB total  |
|          |  | o nginx         |    |                  |
|          |  +---------------------+    |  Disk I/O        |
|          |                             |  R 2.0 GB        |
| [gear]   |                             |  W 1.0 GB        |
+----------+-----------------------------+------------------+
```

- Detail panel width: ~240px
- Slides in with `.smooth` animation
- Clicking the same row again or the X button dismisses it
- Selecting a different container swaps content with crossfade
- Uses OLED dark card style consistent with the rest of the app

### Menu Bar Popover — Slide-In Panel

The popover (`DashboardView`) already has three slide-in states: dashboard, settings, edit. Container detail becomes the 4th state:

```
+--------------------------------+
| <- Back            pihole      |
+--------------------------------+
|                                |
|  * Running         Up 26d 4h  |
|                                |
|  CPU                           |
|  ========..........  2.4%     |
|                                |
|  Memory                        |
|  ================..  142/512  |
|                                |
|  +----------------------------+|
|  | Network                    ||
|  | v 1.0 GB    ^ 500 MB      ||
|  +----------------------------+|
|  | Disk I/O                   ||
|  | R 2.0 GB    W 1.0 GB      ||
|  +----------------------------+|
|                                |
+--------------------------------+
```

- "Back" slides back to the dashboard using the existing `.move(edge:)` transition
- CPU and memory show progress bars (`ProgressBarView`) with orange/cyan tints
- Network and disk I/O displayed as cumulative totals via `ByteFormatter`

### Shared Component: ContainerDetailView

A single `ContainerDetailView` renders the detail layout. It takes a `DockerContainer` and works in both surfaces. The parent view controls the chrome (back button, panel width, slide animation).

Detail sections:
1. **Header** — Container name, status dot + label, uptime computed from `startedAt`
2. **CPU** — Progress bar with percentage, PID count
3. **Memory** — Progress bar showing `usageMB / limitMB`, percentage
4. **Network** — Download (RX) and Upload (TX) totals, formatted with `ByteFormatter`
5. **Disk I/O** — Read and Write totals, formatted with `ByteFormatter`

<!-- TODO: Future sections for ContainerDetailView:
     - Port mappings table (host:container/protocol)
     - Health check status badge + last check output
     - Restart count
     - Container actions bar (Start/Stop/Restart buttons) -->

---

## Build Order

Each step compiles and runs independently.

### Step 1 — Expand the model
- Update `DockerContainer` with new fields + TODO comments for deferred fields
- Update `MockDataProvider.generateContainers()` with realistic mock values

### Step 2 — Container detail view
- New `ContainerDetailView.swift` — shared component
- Renders status header, CPU/memory progress bars, network card, disk I/O card
- Reuses `ProgressBarView`, `ByteFormatter`, Theme card styles

### Step 3 — Full window integration
- Add `selectedContainer` state to `MainDashboardView`
- Make `ContainerTableView` rows tappable (selection callback)
- Slide-in right panel showing `ContainerDetailView`
- Click same row or X to dismiss

### Step 4 — Popover integration
- Add `selectedContainer` as 4th panel state in `DashboardView`
- Make `ContainerListView` / `ContainerRowView` tappable (callback)
- Slide-in `ContainerDetailView` with back button
- Same transition pattern as settings/edit panels

### Step 5 — TODO comments
- Hybrid WebSocket note in README architecture section
- Deferred model fields (ports, health, restartCount) in DockerContainer
- Container actions placeholder in ContainerDetailView

---

## What This Does NOT Include

- **The Go agent** — Built separately in `deskmon-agent` repo
- **Real HTTP networking** — App still uses mock data; networking layer is a separate task
- **Container actions** — No start/stop/restart buttons yet (future, requires agent POST endpoints)
- **Health checks** — Deferred until agent supports it
- **Port mappings** — Deferred until agent supports it
- **Historical data / graphs** — Phase 4 per roadmap
