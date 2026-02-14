# Agent Accuracy Fixes + QoL Improvements

## Summary

Three improvements: fix agent data accuracy (multi-disk, network filtering, packet errors, temperature), add macOS notification alerts, and build per-disk capacity UI.

---

## 1. Agent Data Fixes

### 1a. Multi-Disk Support

**Agent (`internal/collector/system.go`):**

New struct:
```go
type DiskInfo struct {
    MountPoint string  `json:"mountPoint"`
    Device     string  `json:"device"`
    FsType     string  `json:"fsType"`
    UsedBytes  uint64  `json:"usedBytes"`
    TotalBytes uint64  `json:"totalBytes"`
}
```

Replace `readDisk() DiskStats` with `readDisks() []DiskInfo`:
- Parse `/proc/mounts` line by line
- Filter pseudo-filesystems: `tmpfs`, `devtmpfs`, `sysfs`, `proc`, `cgroup*`, `overlay`, `nsfs`, `fuse.lxcfs`, `squashfs`
- Deduplicate by device path (keep first mount per device)
- Call `syscall.Statfs()` on each mount, use `Bavail` (not `Bfree`) for user-available space
- `SystemStats.Disk DiskStats` becomes `SystemStats.Disks []DiskInfo`

**SSE payload change:** `"disk": {...}` becomes `"disks": [...]`

### 1b. Network Interface Filtering

**Agent (`internal/collector/system.go`):**

Default: skip interfaces matching `lo`, `docker*`, `br-*`, `veth*`, `virbr*`.

Extend `NetworkStats`:
```go
type NetworkStats struct {
    DownloadBytesPerSec float64 `json:"downloadBytesPerSec"`
    UploadBytesPerSec   float64 `json:"uploadBytesPerSec"`
    RxErrors            uint64  `json:"rxErrors"`
    RxDrops             uint64  `json:"rxDrops"`
    TxErrors            uint64  `json:"txErrors"`
    TxDrops             uint64  `json:"txDrops"`
}

type NetworkReport struct {
    Physical NetworkStats `json:"physical"`
    Virtual  NetworkStats `json:"virtual"`
}
```

- `readNetSample()` splits interfaces into physical vs virtual buckets
- Both are always computed; `virtual` is omitted from JSON when all zeros (`omitempty`)
- SSE payload: `"network"` becomes `NetworkReport` with `physical` + optional `virtual`

### 1c. Network Packet Errors/Drops

**Agent:** `/proc/net/dev` fields 2 (rx_errors), 3 (rx_drops), 10 (tx_errors), 11 (tx_drops) are already in the file. Parse them into `NetworkStats` fields. Report as delta-per-second like bandwidth.

**Client:** Hidden when all zero. When non-zero, show inline warning badge on the network card (e.g., "3 drops/s" in red text).

### 1d. Temperature Availability

**Agent:** Add `TemperatureAvailable bool` to `CPUStats`. True only if at least one thermal zone returned a reading > 0.

**Client:** Hide the temperature pill in the status bar when `temperatureAvailable == false`.

---

## 2. macOS Notification Alerts

### AlertManager (`deskmon/Services/AlertManager.swift`)

`@Observable` class, injected via `.environment()`.

Responsibilities:
- Receives every SSE system + container event from ServerManager
- Evaluates per-server alert rules against incoming data
- Fires `UNUserNotificationCenter` local notifications
- Cooldown: same alert type + server won't re-fire within 5 minutes

### Alert Rules (per-server, user-configurable)

| Alert            | Default Threshold | Sustained  | Default On |
|------------------|-------------------|------------|------------|
| CPU high         | > 90%             | 30 seconds | Yes        |
| Memory high      | > 95%             | 30 seconds | Yes        |
| Disk high        | > 90% (per disk)  | Instant    | Yes        |
| Container down   | running → stopped  | Instant    | Yes        |
| Network errors   | > 0 drops/errors   | 10 seconds | Yes        |

Each rule: `enabled: Bool`, `threshold: Double` (where applicable), `sustainedSeconds: Int`.

### Sustained Alert Logic

For CPU/Memory/Network errors:
- Track `firstBreachTime: Date?` per rule per server
- On each event: if metric exceeds threshold and `firstBreachTime` is nil, set it to now
- If metric exceeds threshold and `now - firstBreachTime >= sustainedSeconds`, fire notification and start cooldown
- If metric drops below threshold, reset `firstBreachTime`

For Disk/Container: fire immediately (no sustained window needed).

### Storage

`AlertConfig` struct per server stored in `UserDefaults` keyed by server UUID. Default config created when server is added.

```swift
struct AlertConfig: Codable {
    var cpuEnabled: Bool = true
    var cpuThreshold: Double = 90
    var cpuSustained: Int = 30

    var memoryEnabled: Bool = true
    var memoryThreshold: Double = 95
    var memorySustained: Int = 30

    var diskEnabled: Bool = true
    var diskThreshold: Double = 90

    var containerDownEnabled: Bool = true

    var networkErrorsEnabled: Bool = true
    var networkErrorsSustained: Int = 10
}
```

### Settings UI

New "Alerts" section accessible from `EditServerSheet` or a gear icon on the server row:
- Toggle per alert type
- Slider for CPU/Memory/Disk thresholds
- "Test Notification" button to verify permissions

### Notification Format

```
Title:   "prowl — CPU Critical"
Body:    "CPU at 94% for 30s"
Sound:   default
Group:   server UUID string
```

- Container down: "prowl — Container Down: nginx stopped"
- Disk: "prowl — Disk Critical: /data at 92%"
- Tapping notification selects that server in the app

### Permission Flow

- Request `UNUserNotificationCenter` authorization on first server add
- If denied, show subtle banner in settings: "Notifications disabled in System Settings"

---

## 3. Per-Disk Capacity UI

### Client Data Model

New struct:
```swift
struct DiskInfo: Codable, Identifiable, Sendable {
    let mountPoint: String
    let device: String
    let fsType: String
    let usedBytes: UInt64
    let totalBytes: UInt64

    var id: String { mountPoint }
    var usagePercent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0 }
}
```

`ServerStats.disk` becomes `ServerStats.disks: [DiskInfo]`.

Backward compat: if agent sends old `"disk"` key, decode as single `DiskInfo` with mountPoint `/`.

### Menu Bar View (SystemStatsView)

Compact vertical stack — one row per disk:
```
CPU    48%  ████████░░░░░░
MEM    72%  ██████████░░░░
/      45%  ███████░░░░░░░
/data  81%  ████████████░░
```

- Mount label: last path component (e.g., `/mnt/backup` → `backup`), root stays `/`
- Color: green < 75%, yellow 75-90%, red > 90%
- Single disk looks identical to today

### Window View (SystemMetricsCard)

- 1-2 disks: inline gauge cards like CPU/Memory
- 3+ disks: compact list (mount + bar + "18.2 / 50 GB" + percentage)
- Each card shows mount name, used/total formatted, percentage, colored progress bar

### Alert Integration

Disk alert evaluates each disk independently. Notification specifies which mount crossed threshold.

---

## Implementation Order

1. **Agent: multi-disk** — `readDisks()`, update `SystemStats`, update SSE payload
2. **Agent: network filtering + errors** — split physical/virtual, parse error columns
3. **Agent: temperature flag** — `TemperatureAvailable` field
4. **Client: update models** — `DiskInfo`, `NetworkReport`, temperature optional
5. **Client: per-disk UI** — `SystemStatsView` + `SystemMetricsCard` updates
6. **Client: network UI** — error badge, virtual traffic toggle
7. **Client: temperature hide** — conditional rendering
8. **Client: AlertManager** — core engine, notification firing, cooldown
9. **Client: alert config UI** — settings, thresholds, test button
10. **Client: notification permission** — request flow, denied state handling

## Verification

1. `go build ./...` and `go test ./...` pass on agent
2. `xcodebuild build` passes on client
3. Agent reports multiple disks on multi-mount system
4. Network stats exclude docker bridges by default
5. Error badge appears only when drops/errors > 0
6. Temperature hidden on VMs without thermal zones
7. Notifications fire when thresholds exceeded for sustained period
8. Notifications respect cooldown (no spam)
9. Per-server alert config persists across app restarts
10. Disk alerts fire per-mount independently
