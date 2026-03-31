#!/usr/bin/env python3
"""
Google Calendar → iCalendar → Radicale PUT (same idea as curl ics-sync, OAuth instead of secret ICS URL).
Config: CALENDAR_SYNC_CONFIG (default /data/calendar.json) — see config/README.md
First-time auth:  python sync.py auth   (see config/README.md for token path and port)
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from icalendar import Calendar as ICalCalendar
from icalendar import Event as ICalEvent

SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]


def env(name: str, default: str | None = None) -> str:
    v = os.environ.get(name, default)
    if v is None or v == "":
        print(f"sync: missing required env {name}", file=sys.stderr)
        sys.exit(1)
    return v


def resolve_google_token_path() -> str:
    """OAuth user token JSON path inside the container (set GOOGLE_TOKEN_PATH in compose)."""
    path = (os.environ.get("GOOGLE_TOKEN_PATH") or "").strip()
    if path:
        return path
    return "/data/token.json"


def resolve_google_credentials_path() -> str:
    """OAuth client credentials JSON path inside the container."""
    path = (os.environ.get("GOOGLE_CREDENTIALS_PATH") or "").strip()
    if path:
        return path
    return "/credentials/google-oauth-client.json"


def load_calendar_config() -> dict:
    path = os.environ.get("CALENDAR_SYNC_CONFIG", "/data/calendar.json")
    if not os.path.isfile(path):
        print(f"sync: missing config {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
    if cfg.get("sync_type") != "google":
        print("sync: sync_type must be google for this image", file=sys.stderr)
        sys.exit(1)
    cid = cfg.get("id")
    if not cid or not isinstance(cid, str):
        print("sync: id is required in config", file=sys.stderr)
        sys.exit(1)
    return cfg


def collection_href(cfg: dict) -> str:
    h = cfg.get("href")
    if isinstance(h, str) and h != "":
        return h
    return cfg["id"]


def display_name(cfg: dict) -> str:
    n = cfg.get("name")
    if isinstance(n, str) and n != "":
        return n
    return cfg["id"]


def radicale_put_url(cfg: dict) -> str:
    base = os.environ.get("RADICALE_BASE_URL", "http://radicale:5232").rstrip("/")
    user = env("RADICALE_USER")
    return f"{base}/{user}/{collection_href(cfg)}"


def load_credentials() -> Credentials:
    token_path = resolve_google_token_path()

    if not os.path.isfile(token_path):
        print(
            "sync: no token file. Run once:\n"
            "  docker compose run --rm -p 8090:8090 <service-name> python sync.py auth\n"
            "  (same service/env as compose so GOOGLE_TOKEN_PATH matches the mounted token file)",
            file=sys.stderr,
        )
        sys.exit(1)

    creds = Credentials.from_authorized_user_file(token_path, SCOPES)

    if creds and creds.valid:
        return creds
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        _save_token(creds, token_path)
        return creds

    print(
        "sync: token invalid or expired without refresh. Delete token and run: python sync.py auth",
        file=sys.stderr,
    )
    sys.exit(1)


def _save_token(creds: Credentials, token_path: str) -> None:
    os.makedirs(os.path.dirname(token_path) or ".", exist_ok=True)
    with open(token_path, "w", encoding="utf-8") as f:
        f.write(creds.to_json())


def cmd_auth() -> None:
    cred_file = resolve_google_credentials_path()
    token_path = resolve_google_token_path()
    port = int(os.environ.get("OAUTH_PORT", "8090"))

    flow = InstalledAppFlow.from_client_secrets_file(cred_file, SCOPES)
    # host= redirect URI (must match GCP). bind_addr= listen address: 0.0.0.0 so Docker -p 8090:8090 can reach the server.
    creds = flow.run_local_server(
        port=port,
        open_browser=False,
        host="127.0.0.1",
        bind_addr="0.0.0.0",
    )
    _save_token(creds, token_path)
    print(f"sync: token saved to {token_path}")


def events_to_ics(events: list[dict], calendar_name: str) -> bytes:
    cal = ICalCalendar()
    cal.add("prodid", "-//sync-google//EN")
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
        ve.add("uid", f"{uid}@google.com" if uid else base64.urlsafe_b64encode(os.urandom(12)).decode())
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


def _parse_dt(s: str) -> datetime:
    if s.endswith("Z"):
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    return datetime.fromisoformat(s)


def fetch_all_events(service, calendar_id: str) -> list[dict]:
    out: list[dict] = []
    page_token = None
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
                print(f"sync: PUT unexpected status {resp.status}", file=sys.stderr)
                sys.exit(1)
    except urllib.error.HTTPError as e:
        print(f"sync: PUT failed {e.code} {e.reason}\n{e.read().decode(errors='replace')}", file=sys.stderr)
        sys.exit(1)


def cmd_sync_loop() -> None:
    interval = int(os.environ.get("SYNC_INTERVAL_SECONDS", "1800"))
    cfg = load_calendar_config()
    cal_id = cfg.get("google_calendar_id") or "primary"
    cal_name = display_name(cfg)
    href = collection_href(cfg)

    rad_user = env("RADICALE_USER")
    rad_pass = env("RADICALE_PASSWORD")
    rad_put = radicale_put_url(cfg)

    creds = load_credentials()
    service = build("calendar", "v3", credentials=creds, cache_discovery=False)

    print(f"sync: interval={interval}s calendar={cal_id} href={href} name={cal_name} put={rad_put}")

    while True:
        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "fetch Google Calendar")
        try:
            events = fetch_all_events(service, cal_id)
            ics = events_to_ics(events, cal_name)
            print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), f"upload {len(events)} events")
            put_radicale(rad_put, rad_user, rad_pass, ics)
        except Exception as e:
            print(f"sync: error {e!r}", file=sys.stderr)
            import traceback

            traceback.print_exc()

        print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), f"sleeping {interval}s")
        time.sleep(interval)


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "auth":
        cmd_auth()
    else:
        cmd_sync_loop()


if __name__ == "__main__":
    main()
