#!/bin/sh
# Download an ICS feed and PUT it into a Radicale calendar collection.
# Config: CALENDAR_SYNC_CONFIG (default /data/calendar.json) — see config/README.md
set -eu

CONFIG="${CALENDAR_SYNC_CONFIG:-/data/calendar.json}"
INTERVAL="${SYNC_INTERVAL_SECONDS:-1800}"
: "${RADICALE_USER:?RADICALE_USER is required}"
: "${RADICALE_PASSWORD:?RADICALE_PASSWORD is required}"

if ! [ -f "$CONFIG" ]; then
  echo "ics-sync: missing config $CONFIG" >&2
  exit 1
fi

SYNC_TYPE=$(jq -r '.sync_type' "$CONFIG")
if [ "$SYNC_TYPE" != "ics" ]; then
  echo "ics-sync: sync_type must be ics (got $SYNC_TYPE)" >&2
  exit 1
fi

COLLECTION_ID=$(jq -r '.id // empty' "$CONFIG")
if [ -z "$COLLECTION_ID" ]; then
  echo "ics-sync: id is required in config" >&2
  exit 1
fi

COLLECTION_HREF=$(jq -r '.href // .id' "$CONFIG")
CAL_NAME=$(jq -r '.name // .id' "$CONFIG")

ICS_URL=$(jq -r '.external_ics_url // empty' "$CONFIG")
if [ -z "$ICS_URL" ]; then
  echo "ics-sync: external_ics_url is required when sync_type is ics" >&2
  exit 1
fi

BASE="${RADICALE_BASE_URL:-http://radicale:5232}"
BASE=$(echo "$BASE" | sed 's:/*$::')
RADICALE_PUT_URL="${BASE}/${RADICALE_USER}/${COLLECTION_HREF}"

echo "ics-sync: interval=${INTERVAL}s href=${COLLECTION_HREF} name=${CAL_NAME} put=${RADICALE_PUT_URL}"

while true; do
  echo "$(date -Iseconds 2>/dev/null || date) download"
  curl -fsSL "$ICS_URL" -o /tmp/cal.raw

  echo "$(date -Iseconds 2>/dev/null || date) set calendar name"
  python3 /ics_set_name.py "$CAL_NAME" < /tmp/cal.raw > /tmp/cal.ics

  echo "$(date -Iseconds 2>/dev/null || date) upload"
  curl -fsS -u "${RADICALE_USER}:${RADICALE_PASSWORD}" \
    -X PUT \
    -H "Content-Type: text/calendar; charset=utf-8" \
    "${RADICALE_PUT_URL}" \
    --data-binary @/tmp/cal.ics

  echo "$(date -Iseconds 2>/dev/null || date) sleeping ${INTERVAL}s"
  sleep "$INTERVAL"
done
