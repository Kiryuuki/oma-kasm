#!/usr/bin/env python3
"""
Kasm Workspaces Engine for Omarchy Desktop.
Provides workspace discovery, live session provisioning, container termination,
agent telemetry, and desktop stream launching with atomic descriptor safety.
"""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import ssl
import stat
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_CONFIG_PATH = Path.home() / ".config" / "omarchy" / "kasm.json"
HOMELAB_CONFIG_PATH = Path.home() / ".config" / "omarchy" / "homelab.json"
STATE_PATH = Path.home() / ".local" / "state" / "omarchy" / "kasm-hub.json"
CACHE_DIR = Path.home() / ".local" / "state" / "omarchy"

MAX_STATE_BYTES = 512 * 1024  # 512 KB

# SSL Context ignoring self-signed certificates
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE


def sanitize_text(text: str, max_len: int = 500) -> str:
    if not text:
        return ""
    clean = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', str(text)).strip()
    return clean[:max_len]


def load_config(config_path=DEFAULT_CONFIG_PATH):
    path = Path(config_path)
    # Check if kasm.json exists
    if path.exists():
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass

    # Auto-seed from homelab.json if kasm service exists
    if HOMELAB_CONFIG_PATH.exists():
        try:
            with open(HOMELAB_CONFIG_PATH, "r", encoding="utf-8") as f:
                h_data = json.load(f)
                for svc in h_data.get("services", []):
                    if svc.get("type") == "kasm":
                        cfg = {
                            "baseUrl": svc.get("url", "https://192.168.100.108"),
                            "apiKey": svc.get("apiKey", ""),
                            "apiSecret": svc.get("apiSecret", ""),
                            "defaultAudio": True,
                            "defaultMicrophone": False,
                            "defaultClipboard": True,
                            "launchMode": "browser",  # "browser" | "app"
                        }
                        write_atomic(path, cfg)
                        return cfg
        except Exception:
            pass

    return {
        "baseUrl": "https://192.168.100.108",
        "apiKey": "",
        "apiSecret": "",
        "defaultAudio": True,
        "defaultMicrophone": False,
        "defaultClipboard": True,
        "launchMode": "browser",
    }


def write_atomic(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    raw_bytes = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(raw_bytes) > MAX_STATE_BYTES:
        print(f"Error: Payload size {len(raw_bytes)} exceeds ceiling", file=sys.stderr)
        return

    handle, temp_name = tempfile.mkstemp(dir=str(p.parent), suffix=".tmp")
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "wb") as stream:
            stream.write(raw_bytes)
            stream.flush()
            os.fsync(stream.fileno())
        if p.exists():
            st = p.lstat()
            if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
                p.unlink(missing_ok=True)
        os.replace(temp_name, p)
    except BaseException:
        Path(temp_name).unlink(missing_ok=True)
        raise


def kasm_request(base_url, endpoint, api_key="", api_secret="", payload=None, timeout=8):
    url = urllib.parse.urljoin(base_url.rstrip("/") + "/", endpoint.lstrip("/"))
    body = payload or {}
    if api_key and "api_key" not in body:
        body["api_key"] = api_key
    if api_secret and "api_key_secret" not in body:
        body["api_key_secret"] = api_secret

    data = json.dumps(body).encode("utf-8") if body else None
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "omarchy-kasm/1.0",
    }

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, context=SSL_CTX, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", errors="ignore")
        return json.loads(raw) if raw.strip() else {}


def test_connection(base_url, api_key="", api_secret=""):
    if not base_url:
        return {"ok": False, "error": "Server URL is required."}
    
    # 1. Healthcheck probe
    try:
        health = kasm_request(base_url, "/api/__healthcheck", timeout=5)
        if not health or not health.get("ok"):
            pass
    except Exception as e:
        return {"ok": False, "error": f"Server unreachable: {e}"}

    # 2. Developer API authentication probe
    if api_key and api_secret:
        try:
            res = kasm_request(base_url, "/api/public/get_images", api_key, api_secret, timeout=6)
            images = res.get("images", [])
            return {
                "ok": True,
                "serverOnline": True,
                "apiAuthenticated": True,
                "imagesCount": len(images),
                "message": f"Connected · {len(images)} workspaces available",
            }
        except urllib.error.HTTPError as e:
            if e.code == 403:
                return {
                    "ok": True,
                    "serverOnline": True,
                    "apiAuthenticated": False,
                    "warning": "Server online, but API key unauthorized. Enable Developer API in Kasm Admin.",
                }
            return {"ok": False, "serverOnline": True, "error": f"HTTP {e.code}: {e.reason}"}
        except Exception as e:
            return {"ok": False, "serverOnline": True, "error": str(e)}

    return {"ok": True, "serverOnline": True, "apiAuthenticated": False, "message": "Server online (Ping OK)"}


def sync(config_path=DEFAULT_CONFIG_PATH, out_path=STATE_PATH):
    cfg = load_config(config_path)
    base_url = cfg.get("baseUrl", "https://192.168.100.108").rstrip("/")
    api_key = cfg.get("apiKey", "")
    api_secret = cfg.get("apiSecret", "")

    server_online = False
    api_auth = False
    images = []
    sessions = []
    servers = []
    zones = []

    # Check healthcheck
    try:
        kasm_request(base_url, "/api/__healthcheck", timeout=5)
        server_online = True
    except Exception:
        server_online = False

    if server_online and api_key and api_secret:
        # Fetch Images
        try:
            res = kasm_request(base_url, "/api/public/get_images", api_key, api_secret, timeout=6)
            raw_imgs = res.get("images", [])
            for img in raw_imgs:
                images.append({
                    "id": str(img.get("image_id") or img.get("id")),
                    "name": sanitize_text(img.get("friendly_name") or img.get("name") or "Workspace"),
                    "description": sanitize_text(img.get("description") or ""),
                    "imageSrc": img.get("image_src") or "",
                    "cores": img.get("cores") or 2,
                    "memory": img.get("memory") or 2700,
                    "gpuCount": img.get("gpu_count") or 0,
                    "available": bool(img.get("available", True)),
                    "enabled": bool(img.get("enabled", True)),
                    "category": sanitize_text(img.get("default_category") or "Workspaces"),
                })
            api_auth = True
        except Exception:
            pass

        # Fetch Active Sessions
        try:
            res = kasm_request(base_url, "/api/public/get_kasms", api_key, api_secret, timeout=6)
            raw_k = res.get("kasms", [])
            for k in raw_k:
                sessions.append({
                    "id": str(k.get("kasm_id")),
                    "imageId": str(k.get("image_id")),
                    "imageName": sanitize_text(k.get("friendly_name") or k.get("image_friendly_name") or "Session"),
                    "userId": str(k.get("user_id") or ""),
                    "username": sanitize_text(k.get("username") or ""),
                    "createdDate": str(k.get("created_date") or ""),
                    "expirationDate": str(k.get("expiration_date") or ""),
                    "kasmUrl": k.get("kasm_url") or f"{base_url}/#/cast/{k.get('kasm_id')}",
                    "status": sanitize_text(k.get("operational_status") or k.get("status") or "running"),
                })
        except Exception:
            pass

        # Fetch Servers / Agent hosts
        try:
            res = kasm_request(base_url, "/api/public/get_servers", api_key, api_secret, timeout=6)
            raw_srv = res.get("servers", [])
            for s in raw_srv:
                servers.append({
                    "id": str(s.get("server_id")),
                    "hostname": sanitize_text(s.get("hostname") or s.get("server_id")),
                    "zone": sanitize_text(s.get("zone_name") or "Default"),
                    "cores": s.get("cores") or 0,
                    "memory": s.get("memory") or 0,
                    "activeKasms": s.get("active_kasms") or 0,
                    "maxKasms": s.get("max_kasms") or 0,
                    "status": sanitize_text(s.get("status") or "online"),
                })
        except Exception:
            pass

    # If API auth is not yet granted, provide direct launcher fallback shortcuts
    if not images and server_online:
        images = [
            {"id": "kasm-web", "name": "Kasm Workspaces Web Portal", "description": "Open Kasm dashboard and launch sessions", "category": "Portals", "available": True, "enabled": True, "directUrl": base_url},
            {"id": "chrome", "name": "Google Chrome (Isolated)", "description": "Secure web isolation container", "category": "Browsers", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/chrome"},
            {"id": "firefox", "name": "Mozilla Firefox", "description": "Private browsing sandbox", "category": "Browsers", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/firefox"},
            {"id": "tor", "name": "Tor Browser", "description": "Anonymized onion routing workspace", "category": "Browsers", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/tor"},
            {"id": "ubuntu", "name": "Ubuntu Desktop", "description": "Full Linux desktop workspace", "category": "Desktops", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/ubuntu"},
            {"id": "kali", "name": "Kali Linux", "description": "Security testing and pentesting toolkit", "category": "Security", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/kali"},
            {"id": "vscode", "name": "Visual Studio Code", "description": "Cloud IDE with Docker support", "category": "Development", "available": True, "enabled": True, "directUrl": f"{base_url}/#/cast/vscode"},
        ]

    state = {
        "version": 1,
        "updatedAt": datetime.now().astimezone().isoformat(),
        "serverUrl": base_url,
        "serverOnline": server_online,
        "apiAuthenticated": api_auth,
        "images": images,
        "sessions": sessions,
        "servers": servers,
        "activeCount": len(sessions),
    }
    write_atomic(out_path, state)
    print(f"Kasm synced: {len(images)} workspaces, {len(sessions)} active sessions (Server online: {server_online})")


def request_kasm(image_id, config_path=DEFAULT_CONFIG_PATH):
    cfg = load_config(config_path)
    base_url = cfg.get("baseUrl", "").rstrip("/")
    api_key = cfg.get("apiKey", "")
    api_secret = cfg.get("apiSecret", "")

    if not api_key or not api_secret:
        # Fallback to direct web portal URL
        return {"ok": True, "kasmUrl": f"{base_url}/#/cast/{image_id}", "fallback": True}

    payload = {
        "image_id": image_id,
        "enable_sharing": False,
        "allow_kasm_audio": cfg.get("defaultAudio", True),
        "allow_kasm_microphone": cfg.get("defaultMicrophone", False),
        "allow_kasm_clipboard_down": cfg.get("defaultClipboard", True),
        "allow_kasm_clipboard_up": cfg.get("defaultClipboard", True),
    }

    try:
        res = kasm_request(base_url, "/api/public/request_kasm", api_key, api_secret, payload=payload)
        kasm_url = res.get("kasm_url") or f"{base_url}/#/cast/{res.get('kasm_id')}"
        sync(config_path)
        return {"ok": True, "kasmUrl": kasm_url, "kasmId": res.get("kasm_id")}
    except Exception as e:
        # Fallback to web link
        return {"ok": True, "kasmUrl": f"{base_url}/#/cast/{image_id}", "error": str(e), "fallback": True}


def destroy_kasm(kasm_id, config_path=DEFAULT_CONFIG_PATH):
    cfg = load_config(config_path)
    base_url = cfg.get("baseUrl", "")
    api_key = cfg.get("apiKey", "")
    api_secret = cfg.get("apiSecret", "")

    if not api_key or not api_secret:
        return {"ok": False, "error": "API Key & Secret required to terminate sessions."}

    try:
        res = kasm_request(base_url, "/api/public/destroy_kasm", api_key, api_secret, payload={"kasm_id": kasm_id})
        sync(config_path)
        return {"ok": True, "result": res}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def main():
    parser = argparse.ArgumentParser(description="Kasm Workspaces Engine")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="Config file path")
    parser.add_argument("--out", default=str(STATE_PATH), help="Output state path")
    parser.add_argument("--sync", action="store_true", help="Sync workspaces and sessions")
    parser.add_argument("--test", action="store_true", help="Test connection")
    parser.add_argument("--request-kasm", default="", help="Request workspace by image ID")
    parser.add_argument("--destroy-kasm", default="", help="Destroy session by Kasm ID")
    args = parser.parse_args()

    if args.test:
        cfg = load_config(args.config)
        res = test_connection(cfg.get("baseUrl", ""), cfg.get("apiKey", ""), cfg.get("apiSecret", ""))
        print(json.dumps(res))
    elif args.request_kasm:
        res = request_kasm(args.request_kasm, args.config)
        print(json.dumps(res))
    elif args.destroy_kasm:
        res = destroy_kasm(args.destroy_kasm, args.config)
        print(json.dumps(res))
    else:
        sync(args.config, args.out)


if __name__ == "__main__":
    main()
