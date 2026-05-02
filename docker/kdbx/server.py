"""MCP tools over a decrypted KeePass .kdbx (PyKeePass)."""

from __future__ import annotations

import os
import re
import threading
import uuid
from typing import Any

import pyotp
from fastmcp import FastMCP
from pykeepass import PyKeePass
from pykeepass.exceptions import CredentialsError
from starlette.responses import JSONResponse

mcp = FastMCP("KeePass KDBX")

_lock = threading.Lock()
_kp: PyKeePass | None = None


def _env_bool(name: str, default: bool = False) -> bool:
    v = os.environ.get(name, "").strip().lower()
    if not v:
        return default
    return v in ("1", "true", "yes", "on")


def _open_db() -> PyKeePass:
    path = os.environ.get("KDBX_PATH", "").strip()
    if not path:
        raise RuntimeError("KDBX_PATH is not set (path to the .kdbx inside the container)")
    password = os.environ.get("KDBX_PASSWORD")
    if password is not None and password.strip() == "":
        password = None
    keyfile = os.environ.get("KDBX_KEYFILE")
    keyfile = keyfile.strip() if keyfile else None
    try:
        return PyKeePass(path, password=password, keyfile=keyfile)
    except CredentialsError as e:
        raise RuntimeError("Failed to open database (wrong password or keyfile)") from e
    except OSError as e:
        raise RuntimeError(f"Cannot read KDBX at {path!r}") from e


def _get_kp() -> PyKeePass:
    global _kp
    with _lock:
        if _kp is None:
            _kp = _open_db()
        return _kp


def _entry_path(entry: Any) -> str:
    p = entry.path
    if not p:
        return entry.title or ""
    return "/".join("" if x is None else str(x) for x in p)


def _entry_uuid_hex(entry: Any) -> str:
    u = entry.uuid
    return u.hex() if isinstance(u, (bytes, bytearray)) else str(u)


@mcp.custom_route("/healthz", methods=["GET"])
async def healthz(_request: Any) -> JSONResponse:
    return JSONResponse({"status": "ok", "service": "kdbx-mcp"})


@mcp.tool
def kdbx_search(query: str, limit: int = 30) -> list[dict[str, Any]]:
    """Search entries by title (substring, case-insensitive). Returns uuid, title, path, username, url — not passwords."""
    kp = _get_kp()
    if limit < 1:
        limit = 1
    if limit > 200:
        limit = 200
    pattern = f"(?i).*{re.escape(query)}.*"
    found = kp.find_entries(title=pattern, regex=True, recursive=True, history=False)
    out: list[dict[str, Any]] = []
    for e in list(found)[:limit]:
        out.append(
            {
                "uuid": _entry_uuid_hex(e),
                "title": e.title,
                "path": _entry_path(e),
                "username": e.username,
                "url": e.url,
            }
        )
    return out


@mcp.tool
def kdbx_get_entry(
    uuid_hex: str,
    include_password: bool = False,
    include_notes: bool = False,
    include_totp: bool = False,
) -> dict[str, Any]:
    """Load one entry by UUID (hex string from kdbx_search). Optional secrets: password, notes, current TOTP code."""
    kp = _get_kp()
    uuid_hex = uuid_hex.strip().lower().replace("-", "")
    try:
        raw = bytes.fromhex(uuid_hex)
    except ValueError as e:
        raise ValueError("uuid_hex must be a 32-character hex string") from e
    entry = kp.find_entries(uuid=uuid.UUID(bytes=raw), first=True)
    if entry is None:
        raise ValueError("No entry with that UUID")

    data: dict[str, Any] = {
        "uuid": _entry_uuid_hex(entry),
        "title": entry.title,
        "path": _entry_path(entry),
        "username": entry.username,
        "url": entry.url,
    }
    if include_notes:
        data["notes"] = entry.notes or ""
    if include_password:
        if not _env_bool("KDBX_ALLOW_PASSWORD_EXPORT", False):
            raise RuntimeError(
                "Refusing to return password: set KDBX_ALLOW_PASSWORD_EXPORT=1 if you intend to expose passwords via MCP"
            )
        data["password"] = entry.password or ""
    if include_totp:
        otp_uri = getattr(entry, "otp", None) or ""
        if not otp_uri:
            data["totp"] = None
        else:
            try:
                totp = pyotp.parse_uri(otp_uri)
                data["totp"] = totp.now()
            except Exception as exc:  # noqa: BLE001
                data["totp"] = None
                data["totp_error"] = str(exc)
    return data


@mcp.tool
def kdbx_list_groups(max_depth: int = 6) -> list[dict[str, Any]]:
    """List top-level groups (name, uuid) for orientation. Subgroups are not expanded past depth within each branch."""
    kp = _get_kp()
    root = kp.root_group
    max_depth = max(1, min(max_depth, 20))

    def walk(g: Any, depth: int) -> list[dict[str, Any]]:
        rows: list[dict[str, Any]] = []
        if depth > max_depth:
            return rows
        for sg in g.subgroups:
            rows.append({"name": sg.name, "uuid": _entry_uuid_hex(sg), "depth": depth})
            rows.extend(walk(sg, depth + 1))
        return rows

    out: list[dict[str, Any]] = [{"name": root.name, "uuid": _entry_uuid_hex(root), "depth": 0}]
    out.extend(walk(root, 1))
    return out


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
