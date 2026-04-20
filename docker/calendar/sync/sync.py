#!/usr/bin/env python3
"""
calendar-sync: one image for multiple calendar sync modes.

Config JSON is read from CALENDAR_SYNC_CONFIG (default /data/calendar.json).

Supported sync types:
- "google": Google Calendar -> ICS -> Radicale PUT (OAuth)
- "ics":    External ICS URL -> (optional X-WR-CALNAME) -> Radicale PUT

First-time Google auth:
  docker compose run --rm -p 8090:8090 <service> python sync.py auth
"""

from __future__ import annotations

import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from icalendar import Calendar as ICalCalendar
from icalendar import Event as ICalEvent

SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]


def _die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def env(name: str, default: str | None = None) -> str:
    v = os.environ.get(name, default)
    if v is None or v == "":
        _die(f"sync: missing required env {name}")
    return v


def load_calendar_config() -> dict[str, Any]:
    path = os.environ.get("CALENDAR_SYNC_CONFIG", "/data/calendar.json")
    if not os.path.isfile(path):
        _die(f"sync: missing config {path}")
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
    if not isinstance(cfg, dict):
        _die("sync: calendar config must be a JSON object")

    cid = cfg.get("id")
    if not cid or not isinstance(cid, str):
        _die("sync: id is required in config")

    st = cfg.get("sync_type")
    if st not in ("google", "ics"):
        _die('sync: sync_type must be "google" or "ics"')
    return cfg


def collection_href(cfg: dict[str, Any]) -> str:
    h = cfg.get("href")
    if isinstance(h, str) and h != "":
        return h
    return str(cfg["id"])


def display_name(cfg: dict[str, Any]) -> str:
    n = cfg.get("name")
    if isinstance(n, str) and n != "":
        return n
    return str(cfg["id"])


def radicale_put_url(cfg: dict[str, Any]) -> str:
    base = os.environ.get("RADICALE_BASE_URL", "http://radicale:5232").rstrip("/")
    user = env("RADICALE_USER")
    return f"{base}/{user}/{collection_href(cfg)}"


def put_radicale(url: str, user: str, password: str, body: bytes) -> None:
    req = urllib.request.Request(
        url,
        data=body,
        method="PUT",
        headers={"Content-Type": "text/calendar; charset=utf-8"},
    )
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    req.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            if resp.status not in (200, 201, 204):
                _die(f"sync: PUT unexpected status {resp.status}")
    except urllib.error.HTTPError as e:
        _die(f"sync: PUT failed {e.code} {e.reason}\n{e.read().decode(errors='replace')}")


# -------------------------
# ICS mode (external feed)
# -------------------------


def _escape_ics_text(s: str) -> str:
    out: list[str] = []
    for c in s:
        if c in "\\;,":
            out.append("\\" + c)
        elif c == "\n":
            out.append("\\n")
        else:
            out.append(c)
    return "".join(out)


def _set_x_wr_calname(ics_text: str, name: str) -> str:
    # Remove existing X-WR-CALNAME (including folded continuation lines).
    ics_text = re.sub(
        r"\r?\nX-WR-CALNAME[^\r\n]*(?:\r?\n[ \t][^\r\n]*)*",
        "",
        ics_text,
    )
    repl = r"\1X-WR-CALNAME:" + _escape_ics_text(name) + "\n"
    out, n = re.subn(r"(BEGIN:VCALENDAR\r?\n)", repl, ics_text, count=1)
    if n != 1:
        _die("ics-sync: missing BEGIN:VCALENDAR")
    return out


def _download_ics(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "calendar-sync/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def run_ics_loop(cfg: dict[str, Any]) -> None:
    interval = int(os.environ.get("SYNC_INTERVAL_SECONDS", "1800"))
    ics_url = cfg.get("external_ics_url")
    if not isinstance(ics_url, str) or ics_url.strip() == "":
        _die('ics-sync: external_ics_url is required when sync_type is "ics"')

    cal_name = display_name(cfg)
    href = collection_href(cfg)

    rad_user = env("RADICALE_USER")
    rad_pass = env("RADICALE_PASSWORD")
    rad_put = radicale_put_url(cfg)

    print(f"sync(ics): interval={interval}s href={href} name={cal_name} put={rad_put}")
    while True:
        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "download ICS")
        try:
            raw = _download_ics(ics_url)
            # Preserve original bytes unless we need to modify the display name.
            try:
                text = raw.decode("utf-8", errors="replace")
                text = _set_x_wr_calname(text, cal_name)
                body = text.encode("utf-8")
            except Exception as e:
                _die(f"ics-sync: failed to normalize ICS: {e!r}")

            print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "upload")
            put_radicale(rad_put, rad_user, rad_pass, body)
        except Exception as e:
            print(f"sync(ics): error {e!r}", file=sys.stderr)
            import traceback

            traceback.print_exc()
        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), f"sleeping {interval}s")
        time.sleep(interval)


# -------------------------
# Google mode (OAuth)
# -------------------------


def resolve_google_token_path() -> str:
    path = (os.environ.get("GOOGLE_TOKEN_PATH") or "").strip()
    if path:
        return path
    return "/data/token.json"


def resolve_google_credentials_path() -> str:
    path = (os.environ.get("GOOGLE_CREDENTIALS_PATH") or "").strip()
    if path:
        return path
    return "/credentials/google-oauth-client.json"


def _save_token(creds: Credentials, token_path: str) -> None:
    os.makedirs(os.path.dirname(token_path) or ".", exist_ok=True)
    with open(token_path, "w", encoding="utf-8") as f:
        f.write(creds.to_json())


def cmd_google_auth() -> None:
    cred_file = resolve_google_credentials_path()
    token_path = resolve_google_token_path()
    port = int(os.environ.get("OAUTH_PORT", "8090"))

    flow = InstalledAppFlow.from_client_secrets_file(cred_file, SCOPES)
    creds = flow.run_local_server(
        port=port,
        open_browser=False,
        host="127.0.0.1",
        bind_addr="0.0.0.0",
    )
    _save_token(creds, token_path)
    print(f"sync(google): token saved to {token_path}")


def load_google_credentials() -> Credentials:
    token_path = resolve_google_token_path()
    if not os.path.isfile(token_path):
        _die(
            "sync(google): no token file. Run once:\n"
            "  docker compose run --rm -p 8090:8090 <service-name> python sync.py auth\n"
            "  (same service/env as compose so GOOGLE_TOKEN_PATH matches the mounted token file)"
        )

    creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    if creds and creds.valid:
        return creds
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        _save_token(creds, token_path)
        return creds

    _die("sync(google): token invalid or expired without refresh. Delete token and run: python sync.py auth")


def _parse_dt(s: str) -> datetime:
    if s.endswith("Z"):
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    return datetime.fromisoformat(s)


def events_to_ics(events: list[dict[str, Any]], calendar_name: str) -> bytes:
    cal = ICalCalendar()
    cal.add("prodid", "-//calendar-sync//EN")
    cal.add("version", "2.0")
    cal.add("calscale", "GREGORIAN")
    cal.add("x-wr-calname", calendar_name)

    for ev in events:
        if ev.get("status") == "cancelled":
            continue
        if not ev.get("start"):
            continue
        ve = ICalEvent()

        uid = ev.get("id", "")
        if uid:
            ve.add("uid", f"{uid}@google.com")

        if ev.get("summary"):
            ve.add("summary", ev["summary"])
        if ev.get("description"):
            ve.add("description", ev["description"])
        if ev.get("location"):
            ve.add("location", ev["location"])

        start = ev.get("start") or {}
        end = ev.get("end") or {}
        if "dateTime" in start:
            ve.add("dtstart", _parse_dt(start["dateTime"]))
        elif "date" in start:
            ve.add("dtstart", date.fromisoformat(start["date"]))
        if "dateTime" in end:
            ve.add("dtend", _parse_dt(end["dateTime"]))
        elif "date" in end:
            ve.add("dtend", date.fromisoformat(end["date"]))

        updated = ev.get("updated")
        if updated:
            ve.add("dtstamp", _parse_dt(updated))

        cal.add_component(ve)

    return cal.to_ical()


def fetch_all_events(service, calendar_id: str) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    page_token: str | None = None
    time_min = (datetime.now(timezone.utc) - timedelta(days=90)).isoformat()
    time_max = (datetime.now(timezone.utc) + timedelta(days=365 * 2)).isoformat()

    while True:
        req = (
            service.events()
            .list(
                calendarId=calendar_id,
                singleEvents=True,
                orderBy="startTime",
                timeMin=time_min,
                timeMax=time_max,
                pageToken=page_token,
                maxResults=2500,
            )
            .execute()
        )
        out.extend(req.get("items", []))
        page_token = req.get("nextPageToken")
        if not page_token:
            break
    return out


def run_google_loop(cfg: dict[str, Any]) -> None:
    interval = int(os.environ.get("SYNC_INTERVAL_SECONDS", "1800"))
    cal_id = cfg.get("google_calendar_id") or "primary"

    cal_name = display_name(cfg)
    href = collection_href(cfg)

    rad_user = env("RADICALE_USER")
    rad_pass = env("RADICALE_PASSWORD")
    rad_put = radicale_put_url(cfg)

    creds = load_google_credentials()
    service = build("calendar", "v3", credentials=creds, cache_discovery=False)

    print(f"sync(google): interval={interval}s calendar={cal_id} href={href} name={cal_name} put={rad_put}")

    while True:
        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "fetch Google Calendar")
        try:
            events = fetch_all_events(service, str(cal_id))
            ics = events_to_ics(events, cal_name)
            print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), f"upload {len(events)} events")
            put_radicale(rad_put, rad_user, rad_pass, ics)
        except Exception as e:
            print(f"sync(google): error {e!r}", file=sys.stderr)
            import traceback

            traceback.print_exc()

        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), f"sleeping {interval}s")
        time.sleep(interval)


def main() -> None:
    cfg = load_calendar_config()
    st = cfg["sync_type"]

    if len(sys.argv) > 1 and sys.argv[1] == "auth":
        if st != "google":
            _die(f"sync: auth is only valid when sync_type is google (got {st})")
        cmd_google_auth()
        return

    if st == "google":
        run_google_loop(cfg)
    elif st == "ics":
        run_ics_loop(cfg)
    else:
        _die("sync: unreachable")


if __name__ == "__main__":
    main()

