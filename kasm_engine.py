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
import uuid

DEFAULT_CONFIG_PATH = Path.home() / ".config" / "omarchy" / "kasm.json"
HOMELAB_CONFIG_PATH = Path.home() / ".config" / "omarchy" / "homelab.json"
STATE_PATH = Path.home() / ".local" / "state" / "omarchy" / "kasm-hub.json"

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


def format_uuid(val: str) -> str:
    s = str(val or "").strip()
    if len(s) == 32:
        try:
            return str(uuid.UUID(s))
        except Exception:
            pass
    return s


def load_config(config_path=DEFAULT_CONFIG_PATH):
    path = Path(config_path)
    if path.exists():
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass

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
                            "launchMode": "browser",
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


def get_default_user_id(base_url, api_key, api_secret):
    """Retrieves the primary active admin or user ID for session provisioning."""
    try:
        res = kasm_request(base_url, "/api/public/get_users", api_key, api_secret, timeout=5)
        users = res.get("users", [])
        for u in users:
            if "admin" in str(u.get("username", "")).lower() and not u.get("locked") and not u.get("disabled"):
                return u.get("user_id"), u.get("username")
        if users:
            return users[0].get("user_id"), users[0].get("username")
    except Exception:
        pass
    return None, None


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
                    "warning": "API key unauthorized for get_images. Check Access Management in Kasm Admin.",
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
    images_by_id = {}

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
                img_id = str(img.get("image_id") or img.get("id"))
                img_name = sanitize_text(img.get("friendly_name") or img.get("name") or "Workspace")
                has_prof = bool(img.get("persistent_profile_path") or img.get("persistent_profile_config") or img.get("enforce_workspace_persistence"))
                prof_path = sanitize_text(img.get("persistent_profile_path") or "")

                images_by_id[img_id] = img_name
                images_by_id[img_id.replace("-", "")] = img_name
                images_by_id[format_uuid(img_id)] = img_name
                images.append({
                    "id": img_id,
                    "name": img_name,
                    "description": sanitize_text(img.get("description") or ""),
                    "imageSrc": img.get("image_src") or "",
                    "cores": img.get("cores") or 2,
                    "memory": img.get("memory") or 2700,
                    "gpuCount": img.get("gpu_count") or 0,
                    "available": bool(img.get("available", True)),
                    "enabled": bool(img.get("enabled", True)),
                    "hasPersistentProfile": has_prof,
                    "persistentProfilePath": prof_path,
                    "category": sanitize_text(img.get("default_category") or "Workspaces"),
                    "directUrl": f"{base_url}/#/workspaces",
                })
            api_auth = True
        except Exception:
            pass

        # 1. Fetch Active Sessions via get_kasms
        try:
            res = kasm_request(base_url, "/api/public/get_kasms", api_key, api_secret, timeout=6)
            raw_k = res.get("kasms", [])
            for k in raw_k:
                raw_kid = str(k.get("kasm_id") or "")
                fmt_kid = format_uuid(raw_kid)
                srv = k.get("server", {})
                usr = k.get("user", {})
                img_info = k.get("image", {})
                img_id = str(k.get("image_id") or img_info.get("image_id") or "")
                img_name = sanitize_text(img_info.get("friendly_name") or images_by_id.get(img_id) or "Workspace")
                uname = sanitize_text(usr.get("username") or k.get("username") or "")
                uid = str(k.get("user_id") or usr.get("user_id") or "")
                has_prof = bool(k.get("is_persistent_profile") or img_info.get("persistent_profile_path") or img_info.get("persistent_profile_config") or img_info.get("enforce_workspace_persistence"))

                sessions.append({
                    "id": fmt_kid,
                    "rawId": raw_kid,
                    "imageId": img_id,
                    "imageName": img_name,
                    "userId": uid,
                    "username": uname,
                    "hasPersistentProfile": has_prof,
                    "startDate": str(k.get("created_date") or k.get("start_date") or ""),
                    "expirationDate": str(k.get("expiration_date") or ""),
                    "kasmUrl": f"{base_url}/#/session/{fmt_kid}",
                    "serverHostname": sanitize_text(srv.get("hostname") or "proxy"),
                    "status": sanitize_text(k.get("operational_status") or k.get("status") or "running"),
                })
        except Exception:
            pass

        # 2. Fallback to get_users if get_kasms was empty
        if not sessions:
            try:
                res = kasm_request(base_url, "/api/public/get_users", api_key, api_secret, timeout=6)
                users_list = res.get("users", [])
                for u in users_list:
                    uname = u.get("username", "")
                    uid = u.get("user_id", "")
                    for k in u.get("kasms", []):
                        raw_kid = str(k.get("kasm_id") or "")
                        fmt_kid = format_uuid(raw_kid)
                        srv = k.get("server", {})
                        img_id = str(k.get("image_id") or "")
                        disp_name = images_by_id.get(img_id) or images_by_id.get(format_uuid(img_id)) or "Workspace"
                        sessions.append({
                            "id": fmt_kid,
                            "rawId": raw_kid,
                            "imageId": img_id,
                            "imageName": disp_name,
                            "userId": uid,
                            "username": sanitize_text(uname),
                            "startDate": str(k.get("start_date") or ""),
                            "expirationDate": str(k.get("expiration_date") or ""),
                            "kasmUrl": f"{base_url}/#/session/{fmt_kid}",
                            "serverHostname": sanitize_text(srv.get("hostname") or "proxy"),
                            "status": "running",
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

    # Fallback workspaces if none retrieved
    if not images and server_online:
        images = [
            {"id": "kasm-workspaces", "name": "Kasm Workspaces Dashboard", "description": "Open Kasm web portal to launch and manage sessions", "category": "Portals", "available": True, "enabled": True, "directUrl": f"{base_url}/#/workspaces"},
            {"id": "chrome", "name": "Google Chrome (Isolated)", "description": "Secure web isolation container", "category": "Browsers", "available": True, "enabled": True, "directUrl": f"{base_url}/#/workspaces"},
            {"id": "vivaldi", "name": "Vivaldi Browser", "description": "Customizable privacy-first browser", "category": "Browsers", "available": True, "enabled": True, "directUrl": f"{base_url}/#/workspaces"},
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

    fallback_url = f"{base_url}/#/workspaces"

    if not api_key or not api_secret:
        return {"ok": True, "kasmUrl": fallback_url, "fallback": True}

    user_id, username = get_default_user_id(base_url, api_key, api_secret)

    # 1. Check if an active session for this image is ALREADY running for this user
    try:
        current_kasms = kasm_request(base_url, "/api/public/get_kasms", api_key, api_secret, timeout=5).get("kasms", [])
        for k in current_kasms:
            k_img_id = str(k.get("image_id") or k.get("image", {}).get("image_id") or "")
            if k_img_id and (k_img_id == image_id or k_img_id.replace("-", "") == str(image_id).replace("-", "")):
                raw_kid = str(k.get("kasm_id") or "")
                if raw_kid:
                    fmt_kid = format_uuid(raw_kid)
                    full_url = f"{base_url}/#/session/{fmt_kid}"
                    sync(config_path)
                    return {"ok": True, "kasmUrl": full_url, "kasmId": fmt_kid, "resumed": True}
    except Exception:
        pass

    # 2. Check if the requested workspace image supports Persistent Profiles
    has_profile = False
    try:
        images_res = kasm_request(base_url, "/api/public/get_images", api_key, api_secret, timeout=5).get("images", [])
        for img in images_res:
            cur_img_id = str(img.get("image_id") or img.get("id") or "")
            if cur_img_id and (cur_img_id == image_id or cur_img_id.replace("-", "") == str(image_id).replace("-", "")):
                if img.get("persistent_profile_path") or img.get("persistent_profile_config") or img.get("enforce_workspace_persistence"):
                    has_profile = True
                break
    except Exception:
        pass

    payload = {
        "image_id": image_id,
        "enable_sharing": False,
        "persistent_profile_mode": "Enabled",
        "allow_kasm_audio": cfg.get("defaultAudio", True),
        "allow_kasm_microphone": cfg.get("defaultMicrophone", False),
        "allow_kasm_clipboard_down": cfg.get("defaultClipboard", True),
        "allow_kasm_clipboard_up": cfg.get("defaultClipboard", True),
    }
    if user_id:
        payload["user_id"] = user_id

    try:
        res = kasm_request(base_url, "/api/public/request_kasm", api_key, api_secret, payload=payload)
        # Kasm returns relative or absolute kasm_url or session token
        if res.get("kasm_url"):
            rel_url = res["kasm_url"]
            full_url = urllib.parse.urljoin(base_url.rstrip("/") + "/", rel_url.lstrip("/"))
            sync(config_path)
            return {"ok": True, "kasmUrl": full_url, "kasmId": res.get("kasm_id")}
        elif res.get("kasm_id"):
            raw_kid = res["kasm_id"]
            fmt_kid = format_uuid(raw_kid)
            full_url = f"{base_url}/#/session/{fmt_kid}"
            sync(config_path)
            return {"ok": True, "kasmUrl": full_url, "kasmId": fmt_kid}
    except urllib.error.HTTPError as e:
        print(f"request_kasm HTTP {e.code}: {e.read().decode('utf-8', errors='ignore')}", file=sys.stderr)
    except Exception as e:
        print(f"request_kasm error: {e}", file=sys.stderr)

    return {"ok": True, "kasmUrl": fallback_url, "fallback": True}


def destroy_kasm(kasm_id, user_id="", config_path=DEFAULT_CONFIG_PATH):
    cfg = load_config(config_path)
    base_url = cfg.get("baseUrl", "")
    api_key = cfg.get("apiKey", "")
    api_secret = cfg.get("apiSecret", "")

    if not api_key or not api_secret:
        return {"ok": False, "error": "API Key & Secret required to terminate sessions."}

    raw_id = str(kasm_id).replace("-", "")
    if not user_id:
        user_id, _ = get_default_user_id(base_url, api_key, api_secret)

    payload = {"kasm_id": raw_id}
    if user_id:
        payload["user_id"] = user_id

    try:
        res = kasm_request(base_url, "/api/public/destroy_kasm", api_key, api_secret, payload=payload)
        sync(config_path)
        return {"ok": True, "result": res}
    except Exception as e:
        try:
            # Retry with hyphenated UUID
            payload["kasm_id"] = str(kasm_id)
            res = kasm_request(base_url, "/api/public/destroy_kasm", api_key, api_secret, payload=payload)
            sync(config_path)
            return {"ok": True, "result": res}
        except Exception as e2:
            return {"ok": False, "error": str(e2)}


def main():
    parser = argparse.ArgumentParser(description="Kasm Workspaces Engine")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="Config file path")
    parser.add_argument("--out", default=str(STATE_PATH), help="Output state path")
    parser.add_argument("--sync", action="store_true", help="Sync workspaces and sessions")
    parser.add_argument("--save-config", action="store_true", help="Save config JSON passed via stdin with 0600 permissions")
    parser.add_argument("--test", action="store_true", help="Test connection")
    parser.add_argument("--request-kasm", default="", help="Request workspace by image ID")
    parser.add_argument("--destroy-kasm", default="", help="Destroy session by Kasm ID")
    parser.add_argument("--user-id", default="", help="User ID for session actions")
    args = parser.parse_args()

    if args.save_config:
        raw_stdin = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
        if raw_stdin:
            try:
                cfg_data = json.loads(raw_stdin)
                if isinstance(cfg_data, dict):
                    write_atomic(args.config, cfg_data)
                    print(json.dumps({"ok": True}))
                    sys.exit(0)
            except Exception as e:
                print(json.dumps({"ok": False, "error": str(e)}))
                sys.exit(1)
        print(json.dumps({"ok": False, "error": "No config payload provided on stdin"}))
        sys.exit(1)
    elif args.test:
        raw_stdin = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
        if raw_stdin:
            try:
                cfg = json.loads(raw_stdin)
            except Exception:
                cfg = {}
        else:
            cfg = load_config(args.config)
        res = test_connection(cfg.get("baseUrl", ""), cfg.get("apiKey", ""), cfg.get("apiSecret", ""))
        print(json.dumps(res))
    elif args.request_kasm:
        res = request_kasm(args.request_kasm, args.config)
        print(json.dumps(res))
    elif args.destroy_kasm:
        res = destroy_kasm(args.destroy_kasm, args.user_id, args.config)
        print(json.dumps(res))
    else:
        sync(args.config, args.out)


if __name__ == "__main__":
    main()
