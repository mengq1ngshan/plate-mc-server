#!/bin/bash
# ===== 一键启动全家桶:sshd + 樱花 frp + MCSManager =====
# 用法:bash start-services.sh
# 替换下面两个占位符后,再放进容器:
#   <你的访问密钥>  -> https://www.natfrp.com/ 用户中心的访问密钥
#   <隧道ID1>,<隧道ID2> -> natfrp 隧道列表里的隧道 ID(同一节点用逗号分隔)

# ===== sshd =====
mkdir -p /run/sshd
pgrep -x sshd >/dev/null || /usr/sbin/sshd

# ===== 樱花 frp 隧道(公网联机) =====
pgrep -f "frpc -f" >/dev/null || sudo -u natfrp /home/natfrp/frpc -f <你的访问密钥>:<隧道ID1>,<隧道ID2> >/tmp/frp.log 2>&1 &

# ===== MCSManager daemon =====
pgrep -f "mcsmanager/daemon/app.js" >/dev/null || (cd /opt/mcsmanager/daemon && nohup node app.js >/tmp/daemon.log 2>&1 &)

# ===== MCSManager web =====
pgrep -f "mcsmanager/web/app.js" >/dev/null || (cd /opt/mcsmanager/web && nohup node app.js >/tmp/web.log 2>&1 &)

echo "[OK] sshd + frp + MCSManager 已全部就绪"
