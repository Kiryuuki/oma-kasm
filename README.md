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

## Configuration & API Key Setup Guide

### 1. Create a Developer API Key in Kasm Workspaces
1. Open your Kasm Workspaces Admin Web UI (e.g. `https://kasm.local` or `https://192.168.100.108`).
2. Log in as an Administrator.
3. In the left navigation sidebar, go to **Access Management** -> **Developer API** (or **API Keys**).
4. Click **Add API Key** (or edit an existing key).
5. Ensure the following permissions are enabled (or assign the Administrator group):
   - `get_images`: Allows discovering installed workspace Docker images.
   - `request_kasm`: Allows provisioning and starting container streaming sessions.
   - `destroy_kasm`: Allows stopping and deleting active container sessions.
   - `get_kasms` / `get_user_kasm`: Allows listing currently running streaming sessions.
   - `get_servers` / `get_zones`: Allows reading Docker agent server CPU and RAM telemetry.
6. Copy your **API Key** and **API Key Secret**.

### 2. Configure OmaKasm in Omarchy Desktop
Open the plugin Settings flyout (`4` or `s`), enter your Server URL, API Key, and Secret, then click **Save and Sync Now** (or save directly in `~/.config/omarchy/kasm.json`):

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
