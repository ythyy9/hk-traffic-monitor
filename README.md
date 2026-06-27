# 香港中转流量监控

这个小项目用来监控香港中转 VPS 的月流量。页面适合放在 GitHub Pages 上，香港 VPS 使用 `vnStat` 定时更新 `data/traffic.json` 并推送到 GitHub。

默认口径：

- 月额度：250 GB
- 计费方式：双向流量，下载 + 上传
- 数据来源：`vnstat`

## 1. 创建 GitHub 仓库

新建一个仓库，例如：

```text
hk-traffic-monitor
```

把本目录里的文件上传到仓库根目录。然后在 GitHub 仓库设置里开启 Pages：

```text
Settings -> Pages -> Build and deployment -> Deploy from a branch
Branch: main
Folder: /root
```

之后页面地址通常是：

```text
https://你的用户名.github.io/hk-traffic-monitor/
```

## 2. 香港 VPS 安装依赖

SSH 登录香港 VPS 后执行：

```bash
apt update
apt install -y vnstat git python3
systemctl enable --now vnstat
```

确认网卡名称：

```bash
ip route get 1.1.1.1
```

常见是 `eth0`、`ens3` 或 `enp1s0`。

## 3. 在香港 VPS 克隆仓库

推荐用 SSH key 或 GitHub token，让 VPS 可以推送仓库。

示例：

```bash
git clone git@github.com:你的用户名/hk-traffic-monitor.git /opt/hk-traffic-monitor
cd /opt/hk-traffic-monitor
git config user.name "hk-traffic-bot"
git config user.email "hk-traffic-bot@example.com"
```

把脚本设为可执行：

```bash
chmod +x /opt/hk-traffic-monitor/scripts/update-traffic.sh
```

先手动跑一次：

```bash
INTERFACE=eth0 QUOTA_GB=250 /opt/hk-traffic-monitor/scripts/update-traffic.sh
```

如果你的网卡不是 `eth0`，把上面的 `eth0` 换成实际网卡名。

## 4. 设置定时更新

打开 crontab：

```bash
crontab -e
```

加入：

```cron
*/10 * * * * INTERFACE=eth0 QUOTA_GB=250 /opt/hk-traffic-monitor/scripts/update-traffic.sh >/tmp/hk-traffic-monitor.log 2>&1
```

这样每 10 分钟更新一次页面数据。

## 5. 检查是否正常

在 VPS 上看最近统计：

```bash
vnstat
cat /opt/hk-traffic-monitor/data/traffic.json
```

如果 GitHub Pages 页面更新慢，等 1-3 分钟再刷新。

## 安全提醒

不要把服务器密码、x-ui 密码、SOCKS 密码、GitHub token 写进仓库。这个仓库只需要公开流量数字即可。
