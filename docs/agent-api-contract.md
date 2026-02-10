# Deskmon Agent API Contract

What the macOS app expects from `deskmon-agent`. This is the source of truth for the JSON shapes the Swift client will decode.

**Default port:** `7654`
**Auth:** Optional `Authorization: Bearer <token>` header

---

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | No | Simple health check |
| `GET` | `/stats` | Yes | Full payload (system + containers) |
| `GET` | `/stats/system` | Yes | System stats only |
| `GET` | `/stats/docker` | Yes | Docker container stats only |
| `GET` | `/stats/processes` | Yes | Top processes by CPU |
| `GET` | `/stats/services` | Yes | Detected service stats |
| `GET` | `/stats/stream` | Yes | SSE stream of live stats |
| `POST` | `/containers/{id}/start` | Yes | Start a Docker container |
| `POST` | `/containers/{id}/stop` | Yes | Stop a Docker container |
| `POST` | `/containers/{id}/restart` | Yes | Restart a Docker container |
| `POST` | `/processes/{pid}/kill` | Yes | Kill a process by PID |
| `POST` | `/services/{pluginId}/configure` | Yes | Set service credentials (e.g. Pi-hole password) |
| `POST` | `/agent/restart` | Yes | Restart the agent |
| `POST` | `/agent/stop` | Yes | Stop the agent |
| `GET` | `/agent/status` | Yes | Agent version and status |

---

## GET /health

Lightweight check to determine if the agent is reachable.

**Response** `200 OK`

```json
{
  "status": "ok"
}
```

The macOS app uses this to determine server status (healthy vs offline). A non-200 or timeout = offline.

---

## GET /stats

Full system stats and Docker container stats in a single response.

**Response** `200 OK`

```json
{
  "system": {
    "cpu": {
      "usagePercent": 42.5,
      "coreCount": 8,
      "temperature": 64.7
    },
    "memory": {
      "usedBytes": 22548578304,
      "totalBytes": 34359738368
    },
    "disk": {
      "usedBytes": 279172874240,
      "totalBytes": 536870912000
    },
    "network": {
      "downloadBytesPerSec": 13631488.0,
      "uploadBytesPerSec": 3145728.0
    },
    "uptimeSeconds": 1048962
  },
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

System stats are nested under `"system"`. Containers are at the top level alongside it.

If Docker is not installed or the socket is unavailable, `containers` should be an empty array `[]`.

---

## Field Reference

### System Stats

All system fields are nested under the `"system"` key.

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| `system.cpu.usagePercent` | `float64` | `%` (0-100) | Overall CPU usage across all cores |
| `system.cpu.coreCount` | `int` | count | Number of logical CPU cores |
| `system.cpu.temperature` | `float64` | `°C` | CPU package temperature. `0` if unavailable |
| `system.memory.usedBytes` | `uint64` | bytes | Used RAM (excluding buffers/cache) |
| `system.memory.totalBytes` | `uint64` | bytes | Total physical RAM |
| `system.disk.usedBytes` | `uint64` | bytes | Used space on root mount (`/`) |
| `system.disk.totalBytes` | `uint64` | bytes | Total space on root mount (`/`) |
| `system.network.downloadBytesPerSec` | `float64` | bytes/sec | Current download rate across all interfaces |
| `system.network.uploadBytesPerSec` | `float64` | bytes/sec | Current upload rate across all interfaces |
| `system.uptimeSeconds` | `int64` | seconds | System uptime since last boot |

### CPU Usage Calculation

The agent should compute `usagePercent` by sampling `/proc/stat` (or equivalent) at two points and calculating the delta:

```
usage = (delta_user + delta_system + delta_nice + delta_irq + delta_softirq + delta_steal)
        / (delta_total) * 100
```

This must be computed server-side. The macOS app does not do this calculation.

### Network Speed Calculation

The agent should compute bytes-per-second by sampling `/proc/net/dev` (or equivalent) and dividing the byte delta by the time delta between samples. The app expects instantaneous speed, not cumulative totals.

### Temperature

Read from `/sys/class/thermal/thermal_zone*/temp` or `sensors` equivalent. Return `0` if not available (some VMs/containers won't have this). The value should be in Celsius, not millidegrees.

---

### Container Stats

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| `id` | `string` | — | Short container ID (first 12 chars) |
| `name` | `string` | — | Container name (without leading `/`) |
| `image` | `string` | — | Full image name with tag |
| `status` | `string` | enum | `"running"`, `"stopped"`, or `"restarting"` |
| `cpuPercent` | `float64` | `%` (0-100+) | Container CPU usage. Can exceed 100% on multi-core |
| `memoryUsageMB` | `float64` | MB | Current memory usage |
| `memoryLimitMB` | `float64` | MB | Container memory limit. `0` if unlimited |
| `networkRxBytes` | `int64` | bytes | Total bytes received since container start |
| `networkTxBytes` | `int64` | bytes | Total bytes sent since container start |
| `blockReadBytes` | `int64` | bytes | Total bytes read from disk since container start |
| `blockWriteBytes` | `int64` | bytes | Total bytes written to disk since container start |
| `pids` | `int` | count | Current number of processes in the container |
| `startedAt` | `string` | ISO 8601 | Container start time. `null` if stopped |

### Container CPU Calculation

Docker's `/containers/{id}/stats` returns cumulative CPU nanoseconds. The agent must track the previous sample and compute:

```
cpuPercent = (delta_container_cpu / delta_system_cpu) * numCores * 100
```

### Container Status Mapping

Map Docker's container state to one of three values:

| Docker State | Agent Value |
|-------------|-------------|
| `running` | `"running"` |
| `exited`, `dead`, `created` | `"stopped"` |
| `restarting` | `"restarting"` |
| `paused` | `"stopped"` |

### startedAt Format

ISO 8601 with timezone: `"2025-01-15T08:30:00Z"`

The macOS app decodes this with `ISO8601DateFormatter` and computes uptime client-side. Send `null` (not an empty string) for stopped containers.

---

## Server Status Derivation

The macOS app determines server status from the stats response:

| Condition | Status |
|-----------|--------|
| No response / timeout | `offline` |
| CPU > 90% OR Memory > 95% | `critical` |
| CPU > 75% OR Memory > 85% | `warning` |
| Otherwise | `healthy` |

The agent does not need to send a status field. The app computes it.

---

## Error Handling

| Scenario | Expected Behavior |
|----------|-------------------|
| Agent unreachable | App shows server as `offline` |
| Docker not installed | Return `"containers": []` |
| Docker socket permission denied | Return `"containers": []` |
| Temperature unavailable | Return `"temperature": 0` |
| Container memory unlimited | Return `"memoryLimitMB": 0` |

---

## Auth

If the user configures a token in the macOS app, it sends:

```
GET /stats HTTP/1.1
Authorization: Bearer <token>
```

The agent should return `401 Unauthorized` if a token is configured on the agent side and the request doesn't match. If no token is configured on the agent, accept all requests.

---

## GET /stats/stream (SSE)

Server-Sent Events endpoint for live stats. The app opens a persistent connection and receives events.

**Event types:**

| Event | Interval | Payload |
|-------|----------|---------|
| `system` | 1s | `{"system": {...}, "processes": [...]}` |
| `docker` | 5s | `[{container}, ...]` |
| `services` | 10s | `[{service}, ...]` |
| `: keepalive` | 30s | Comment (empty) |

The app connects via: fetch once (`GET /stats`), then open stream (`GET /stats/stream`).
Auto-reconnects with exponential backoff (2s → 4s → 8s → max 30s).

---

## POST /services/{pluginId}/configure

Configure credentials for a detected service (e.g. Pi-hole v6 password).

**Request** `POST /services/pihole/configure`

```json
{
  "password": "your-pihole-password"
}
```

**Response** `200 OK`

```json
{
  "message": "configured"
}
```

The macOS app sends this when the user enters a Pi-hole password in the service dashboard. The agent stores the password in config, authenticates with Pi-hole v6 via `POST /api/auth`, and caches the session. Full Pi-hole stats will appear on the next SSE services event (~10s).

---

## Implemented Container Fields

- `containers[].ports` — Array of port mappings `[{"hostPort": 8080, "containerPort": 80, "protocol": "tcp"}]`
- `containers[].restartCount` — Number of container restarts
- `containers[].healthStatus` — `"healthy"`, `"unhealthy"`, `"starting"`, `"none"`
