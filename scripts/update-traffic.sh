#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/hk-traffic-monitor}"
INTERFACE="${INTERFACE:-eth0}"
QUOTA_GB="${QUOTA_GB:-250}"
DATA_FILE="$REPO_DIR/data/traffic.json"

cd "$REPO_DIR"
mkdir -p "$(dirname "$DATA_FILE")"

vnstat --json -i "$INTERFACE" | python3 - "$INTERFACE" "$QUOTA_GB" "$DATA_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone

iface = sys.argv[1]
quota_gb = float(sys.argv[2])
data_file = sys.argv[3]
raw = sys.stdin.read()
payload = json.loads(raw)

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
now = datetime.now(timezone.utc)

def pick_period(items, kind):
    if not items:
        return {}
    for item in items:
        date = item.get("date", {})
        if kind == "month" and date.get("year") == now.year and date.get("month") == now.month:
            return item
        if kind == "day" and date.get("year") == now.year and date.get("month") == now.month and date.get("day") == now.day:
            return item
    return items[-1]

month = pick_period(traffic.get("month", []), "month")
day = pick_period(traffic.get("day", []), "day")

month_rx = int(month.get("rx", 0))
month_tx = int(month.get("tx", 0))
day_rx = int(day.get("rx", 0))
day_tx = int(day.get("tx", 0))
quota_bytes = int(quota_gb * 1024 * 1024 * 1024)

out = {
    "name": "HK Relay",
    "interface": iface,
    "period": f"{now.year:04d}-{now.month:02d}",
    "quota_gb": quota_gb,
    "quota_bytes": quota_bytes,
    "billing_mode": "bidirectional",
    "month_rx_bytes": month_rx,
    "month_tx_bytes": month_tx,
    "month_total_bytes": month_rx + month_tx,
    "today_rx_bytes": day_rx,
    "today_tx_bytes": day_tx,
    "today_total_bytes": day_rx + day_tx,
    "updated_at": now.isoformat().replace("+00:00", "Z"),
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
