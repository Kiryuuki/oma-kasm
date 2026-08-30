# OmaKasm: Kasm Workspaces Launcher and Session Manager for Omarchy

A keyboard-driven Kasm Workspaces launcher, active container stream monitor, and agent cluster telemetry flyout for the Omarchy Desktop Environment.

---

## Features

- **Workspace Catalog and 1-Click Provisioning**:
  - Search and filter across installed workspace images (Browsers, Linux Desktops, Development Tools, Security).
  - 1-click launch provisions the container session via Kasm Developer API and opens the live web stream directly in your browser.
- **Active Streaming Sessions Monitor**:
  - Real-time list of running container sessions with status indicators and user assignments.
  - 1-click Resume stream and 1-click Terminate container action.
- **Agent Server and Zone Telemetry**:
  - View Docker agent server status, CPU cores, memory allocation, and active container capacity across deployment zones.
- **Configurable Session Defaults**:
  - Audio streaming, microphone pass-through, and bidirectional clipboard sharing preferences.
- **In-Panel Credential Manager**:
  - Configure Server URL, Developer API Key, and Secret directly inside the flyout with live connection testing.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `1` | Switch to Workspaces catalog tab |
| `2` | Switch to Active Sessions tab |
| `3` | Switch to Cluster and Agents tab |
| `4` | Switch to Settings tab |
| `Up` / `Down` or `k` / `j` | Navigate workspaces or active sessions list |
| `Enter` / `Space` | Launch selected workspace or reconnect to session |
| `x` / `Delete` | Terminate selected container session |
| `s` / `S` | Toggle Settings tab |
| `r` / `R` | Trigger instant telemetry sync |
| `Esc` | Clear search focus or close flyout |

---

## Configuration

Credentials can be configured directly inside the plugin Settings tab, or stored in `~/.config/omarchy/kasm.json`:

```json
{
  "baseUrl": "https://192.168.100.108",
  "apiKey": "YOUR_KASM_DEVELOPER_API_KEY",
  "apiSecret": "YOUR_KASM_DEVELOPER_API_SECRET",
  "defaultAudio": true,
  "defaultMicrophone": false,
  "defaultClipboard": true,
  "launchMode": "browser"
}
```

---

## License

Source-Available Non-Commercial License (PolyForm Noncommercial 1.0.0). Free for personal, educational, and homelab use. Commercial sale, distribution for fee, or commercial re-licensing is prohibited without author permission.
