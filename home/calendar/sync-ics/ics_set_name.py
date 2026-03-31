#!/usr/bin/env python3
"""Read ICS on stdin, write stdout with X-WR-CALNAME set from argv[1]."""
from __future__ import annotations

import re
import sys


def escape_ics_text(s: str) -> str:
    out: list[str] = []
    for c in s:
        if c in "\\;,":
            out.append("\\" + c)
        elif c == "\n":
            out.append("\\n")
        else:
            out.append(c)
    return "".join(out)


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: ics_set_name.py <display-name>", file=sys.stderr)
        sys.exit(2)
    name = sys.argv[1]
    data = sys.stdin.read()
    data = re.sub(
        r"\r?\nX-WR-CALNAME[^\r\n]*(?:\r?\n[ \t][^\r\n]*)*",
        "",
        data,
    )
    repl = r"\1X-WR-CALNAME:" + escape_ics_text(name) + "\n"
    data, n = re.subn(r"(BEGIN:VCALENDAR\r?\n)", repl, data, count=1)
    if n != 1:
        print("ics_set_name: missing BEGIN:VCALENDAR", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(data)


if __name__ == "__main__":
    main()
