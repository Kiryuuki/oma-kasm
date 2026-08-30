# OmaKasm: Kasm Workspaces Launcher and Session Manager for Omarchy

A keyboard-driven Kasm Workspaces launcher, active container stream monitor, and agent cluster telemetry flyout for the Omarchy Desktop Environment.

![OmaKasm Preview](preview.png)

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
4. Click **Add API Key** (or edit your existing key).
5. On the main key settings, ensure the **Read Only** toggle switch is set to **OFF**.
6. In the **Permissions** tab, ensure the following permissions are added and active:
   - `Global Admin`: Full administrative access.
   - `User`: Standard user API actions.
   - `Users Auth Session`: Session creation and authentication on behalf of users.
   - `Sessions Delete`: Session termination and container cleanup.
   - `Sessions Modify`: Session parameter modifications.
   - `Sessions View`: Active session monitoring.
   - `Users Create`, `Users Delete`, `Users Modify`, `Users Modify Admin`, `Users View`: User discovery and credential validation.
7. Copy your **API Key** and **API Key Secret**.

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

## Persistent Profiles Support

When launching workspaces through OmaKasm, sessions are dispatched under your authenticated user ID with persistent profile mode enabled by default. If your Kasm workspace image or group policy has Persistent Profiles enabled, Kasm automatically mounts your personal persistent storage directory `/home/kasm-user` into the container. All browser history, downloads, bookmarks, extensions, configurations, and files are permanently preserved across session restarts.

### How to Enable Persistent Profiles on Any Workspace in Kasm Admin:
1. **Per-Workspace Configuration**:
   - In Kasm Admin, go to **Admin** -> **Workspaces**.
   - Edit the desired workspace (e.g. Chrome, Firefox, Ubuntu, VSCode).
   - Set **Persistent Profile Path** to `/data/kasm_profiles/{username}/`.
   - Ensure the volume mapping binds `/data/kasm_profiles/{username}/` to `/home/kasm-user`.
   - Save changes. OmaKasm will automatically detect the profile and display the **`󰋊 Profile`** badge.

2. **Global Group-Wide Configuration**:
   - In Kasm Admin, go to **Access Management** -> **Groups**.
   - Edit your user group (e.g. **Administrators** or **All Users**).
   - In the **Settings** subtab, add or edit the `persistent_profile_path` setting and set it to `/data/kasm_profiles/{username}/`.
   - All workspaces launched by users in this group will automatically mount persistent profile storage.

---

## License

Source-Available Non-Commercial License (PolyForm Noncommercial 1.0.0). Free for personal, educational, and homelab use. Commercial sale, distribution for fee, or commercial re-licensing is prohibited without author permission.
