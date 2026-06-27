#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/hk-traffic-monitor}"
INTERFACE="${INTERFACE:-eth0}"
QUOTA_GB="${QUOTA_GB:-250}"
BILLING_DAY="${BILLING_DAY:-15}"
DATA_FILE="$REPO_DIR/data/traffic.json"
TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

cd "$REPO_DIR"
mkdir -p "$(dirname "$DATA_FILE")"

vnstat --json -i "$INTERFACE" > "$TMP_JSON"
python3 - "$INTERFACE" "$QUOTA_GB" "$BILLING_DAY" "$DATA_FILE" "$TMP_JSON" <<'PY'
import calendar
import json
import sys
from datetime import date, datetime, timedelta, timezone

iface = sys.argv[1]
quota_gb = float(sys.argv[2])
billing_day = int(sys.argv[3])
data_file = sys.argv[4]
vnstat_file = sys.argv[5]

if billing_day < 1 or billing_day > 31:
    raise SystemExit("BILLING_DAY must be between 1 and 31")

with open(vnstat_file, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

interfaces = payload.get("interfaces", [])
selected = None
for item in interfaces:
    if item.get("name") == iface:
        selected = item
        break

if selected is None and interfaces:
    selected = interfaces[0]
    iface = selected.get("name", iface)

if selected is None:
    raise SystemExit("No vnStat interface data found")

traffic = selected.get("traffic", {})
today = date.today()
updated_at = datetime.now(timezone.utc)

def shift_month(year, month, delta):
    total = year * 12 + month - 1 + delta
    return total // 12, total % 12 + 1

def cycle_day(year, month, day):
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, min(day, last_day))

this_cycle_day = cycle_day(today.year, today.month, billing_day)
if today >= this_cycle_day:
    cycle_start = this_cycle_day
    next_year, next_month = shift_month(today.year, today.month, 1)
    cycle_end_exclusive = cycle_day(next_year, next_month, billing_day)
else:
    prev_year, prev_month = shift_month(today.year, today.month, -1)
    cycle_start = cycle_day(prev_year, prev_month, billing_day)
    cycle_end_exclusive = this_cycle_day

cycle_end_display = cycle_end_exclusive - timedelta(days=1)

def day_from_item(item):
    item_date = item.get("date", {})
    try:
        return date(item_date["year"], item_date["month"], item_date["day"])
    except KeyError:
        return None

cycle_rx = 0
cycle_tx = 0
day_rx = 0
day_tx = 0
for item in traffic.get("day", []):
    item_day = day_from_item(item)
    if item_day is None:
        continue
    rx = int(item.get("rx", 0))
    tx = int(item.get("tx", 0))
    if cycle_start <= item_day < cycle_end_exclusive:
        cycle_rx += rx
        cycle_tx += tx
    if item_day == today:
        day_rx += rx
        day_tx += tx

quota_bytes = int(quota_gb * 1024 * 1024 * 1024)

out = {
    "name": "HK Relay",
    "interface": iface,
    "period": f"{cycle_start.isoformat()} 至 {cycle_end_display.isoformat()}",
    "quota_gb": quota_gb,
    "quota_bytes": quota_bytes,
    "billing_cycle_start_day": billing_day,
    "billing_mode": "bidirectional",
    "cycle_rx_bytes": cycle_rx,
    "cycle_tx_bytes": cycle_tx,
    "cycle_total_bytes": cycle_rx + cycle_tx,
    "month_rx_bytes": cycle_rx,
    "month_tx_bytes": cycle_tx,
    "month_total_bytes": cycle_rx + cycle_tx,
    "today_rx_bytes": day_rx,
    "today_tx_bytes": day_tx,
    "today_total_bytes": day_rx + day_tx,
    "updated_at": updated_at.isoformat().replace("+00:00", "Z"),
    "source": "vnstat",
}

with open(data_file, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

git add data/traffic.json
if git diff --cached --quiet; then
  exit 0
fi

git commit -m "Update HK traffic data"
git push
