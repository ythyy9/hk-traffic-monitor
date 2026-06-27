const DATA_URL = "data/traffic.json";
const GB = 1024 ** 3;

const $ = (id) => document.getElementById(id);

function gb(bytes) {
  if (!Number.isFinite(bytes)) return "--";
  return (bytes / GB).toFixed(2);
}

function setStatus(percent, updatedAt) {
  const status = $("status");
  const ageMs = Date.now() - new Date(updatedAt).getTime();
  const stale = !Number.isFinite(ageMs) || ageMs > 90 * 60 * 1000;

  status.className = "status";

  if (stale) {
    status.textContent = "Stale";
    status.classList.add("warn");
    return;
  }

  if (percent >= 95) {
    status.textContent = "Danger";
    status.classList.add("danger");
  } else if (percent >= 80) {
    status.textContent = "Warning";
    status.classList.add("warn");
  } else {
    status.textContent = "Normal";
    status.classList.add("ok");
  }
}

function render(data) {
  const quota = data.quota_bytes || data.quota_gb * GB;
  const monthTotal = data.month_total_bytes || 0;
  const remaining = Math.max(quota - monthTotal, 0);
  const percent = quota > 0 ? (monthTotal / quota) * 100 : 0;
  const clamped = Math.min(percent, 100);

  $("month-percent").textContent = `${percent.toFixed(1)}%`;
  $("month-used").textContent = `${gb(monthTotal)} GB`;
  $("month-quota").textContent = `/ ${gb(quota)} GB`;
  $("remaining").textContent = `${gb(remaining)} GB`;
  $("today-total").textContent = `${gb(data.today_total_bytes || 0)} GB`;
  $("month-rx").textContent = `${gb(data.month_rx_bytes || 0)} GB`;
  $("month-tx").textContent = `${gb(data.month_tx_bytes || 0)} GB`;
  $("iface").textContent = data.interface || "--";
  $("period").textContent = data.period || "--";
  $("billing").textContent =
    data.billing_mode === "bidirectional" ? "双向流量" : "自定义";

  const fill = $("meter-fill");
  fill.style.width = `${clamped}%`;
  fill.className = "meter-fill";
  if (percent >= 95) fill.classList.add("danger");
  else if (percent >= 80) fill.classList.add("warn");

  const updated = data.updated_at
    ? new Date(data.updated_at).toLocaleString("zh-CN", { hour12: false })
    : "--";
  $("updated").textContent = `最后更新：${updated}`;
  setStatus(percent, data.updated_at);
}

async function main() {
  try {
    const response = await fetch(`${DATA_URL}?t=${Date.now()}`, {
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    render(await response.json());
  } catch (error) {
    $("updated").textContent = `读取失败：${error.message}`;
    $("status").textContent = "Error";
    $("status").className = "status danger";
  }
}

main();
