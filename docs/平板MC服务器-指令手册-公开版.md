# 平板 MC 服务器 - 指令手册

> 系统:小米平板 7S Pro(Tiny Container / Debian 13 / proot)
> 服务:剑与王国 Forge 1.20.1(272 mod)+ MCSManager + 樱花 frp + SSH
>
> ⚠️ 本手册是**本机实测速查**,路径/端口/坐标/实例 UUID 均以你的实际环境为准;若服务端迁移过、mods 有增减,mod 相关的判断(如 AllTheLeaks、chunky bug)按你的实际 mod 集灵活处理。

---

## 一、远程入口(Windows)

```powershell
# 连接平板容器
ssh root@<平板IP> -p 8022
```

> 平板 IP 变了就进安卓 设置 → Wi-Fi → 当前网络 查看;proot 里 `ip`/`hostname -I` 不可用。

## 二、一键启动全家桶(推荐)

### 2.1 完整脚本(一次性写入)

```bash
sudo tee /usr/local/bin/start-services.sh > /dev/null <<'EOF'
#!/bin/bash
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
EOF
sudo chmod 755 /usr/local/bin/start-services.sh
```

### 2.2 执行

```bash
bash /usr/local/bin/start-services.sh
```
预期输出:`[OK] sshd + frp + MCSManager 已全部就绪`

### 2.3 验证四服务存活

```bash
pgrep -x sshd                          # 有 PID = 存活
pgrep -f "frpc -f"                     # frp 隧道
pgrep -f "mcsmanager/daemon/app.js"    # MCSManager daemon
pgrep -f "mcsmanager/web/app.js"       # MCSManager web
```

> 打开容器终端也会自动跑(需配 tiny 免密 sudo + bashrc,见《从零部署手册》阶段 10)。

## 三、樱花 frp 隧道(公网联机)

### 3.1 开启隧道

```bash
sudo -u natfrp /home/natfrp/frpc -f 你的访问密钥:<隧道ID1>,<隧道ID2> > /tmp/frp.log 2>&1 &
```

- `你的访问密钥`:natfrp.com 用户中心复制
- `<隧道ID1>,<隧道ID2>`:隧道 ID(mc-server / eureka),逗号分隔,多条隧道须同一节点

### 3.2 确认隧道是否开启(重要)

```bash
cat /tmp/frp.log
```

| 日志内容 | 含义 |
|---|---|
| `隧道启动成功` + `使用 >><frp公网地址><< 连接你的隧道` | ✅ 已开启,公网地址以日志为准 |
| `连接节点成功` 但无隧道信息 | 还在初始化,等几秒再看 |
| `permission denied` / `connect failed` | 网络或密钥问题,重试 |
| `netlink: permission denied` 警告 | ⚠️ proot 正常现象,忽略 |

### 3.3 检查隧道是否在跑

```bash
pgrep -f "frpc -f"
```
有 PID 输出 = 隧道进程存活。

### 3.4 停止隧道

```bash
pkill -f "frpc -f"
```
停止后**公网地址随即失效**,朋友会连不上,重启服务器前记得重新开启。

## 四、手动启动(应急)

```bash
# sshd
mkdir -p /run/sshd && /usr/sbin/sshd

# MCSManager 面板(web + daemon)
cd /opt/mcsmanager/daemon && nohup node app.js > /tmp/daemon.log 2>&1 &
cd /opt/mcsmanager/web && nohup node app.js > /tmp/web.log 2>&1 &
```

> frp 用第三节命令单独管理,不在这里重复。

## 五、MC 服务端(面板托管,这条仅备用)

```bash
cd "/opt/mcsmanager/daemon/data/InstanceData/<实例UUID>/server"
/opt/java17/bin/java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.20/unix_args.txt nogui
```

## 六、服务器控制台命令(面板控制台输入)

| 命令 | 作用 |
|---|---|
| `stop` | 正常停服 |
| `list` | 在线玩家列表 |
| `spark tps` | 查看 TPS(20=满) |
| `spark health` | 健康摘要(内存/GC/实体) |
| `spark dump --thread "Server thread"` | 卡顿时抓服务器线程栈 |
| `chunky radius 2000` | 设置预生成范围 |
| `chunky start` | 开始后台预生成(玩家无感) |

**chunky 完整命令(预生成世界):**

```
chunky center <x> <z>      # 设中心(默认 0,0,务必改成玩家基地/殖民地坐标!)
chunky radius 2000         # 范围
chunky start               # 开始
chunky pause / continue    # 暂停 / 继续
chunky cancel              # 取消(遇生成 bug 立即用)
chunky status              # 进度
```

⚠️ **chunky 实战坑**:
- 默认中心 0,0 可能不覆盖玩家区域 → 先 `chunky center <坐标>`
- **chunky 只生成缺失区块,已探索区域会被快速跳过**——看到"跑得快"别当真,真新区块生成可能只有个位数 cps
- 某些 mod 生成器在特定坐标有 bug(`Empty height range` / `Hanging entity at invalid position`),chunky 碰到会速率暴跌、卡主线程、TPS 崩 → **立即 `chunky cancel` 止损**
- ⛔ **实测教训:殖民地区域(-1170, -3401)附近有生成 bug,chunky 一碰就把服务器干崩**(单 tick 卡 60s → watchdog 强制关服,崩溃报告 block_ticks 180 万)。该区域**绝对不要预生成**;0,0 周边是安全的。watchdog 强杀不损坏已保存区块,崩溃后重启存档完好
- 几万区块会占几个 GB 磁盘

## 七、文件传输(Windows)

```powershell
# 传到平板(必须加 -O,proot 下 SFTP 失效)
scp -O -P 8022 "本地文件路径" root@<平板IP>:/root/

# 从平板取回
scp -O -P 8022 root@<平板IP>:/root/文件路径 本地目录
```

## 八、日常开机流程

1. 打开 **Tiny Container**(自动拉起 sshd + frp + MCSManager)
2. 浏览器打开 `http://<平板IP>:23333`(MCSManager)
3. 面板点 **"剑与王国" → 启动**
4. 确认隧道在跑:SSH 里 `pgrep -f "frpc -f"`(或看 `/tmp/frp.log`)
5. 朋友连公网:`<frp公网地址>`

## 九、性能优化

### 9.0 ⭐ 解锁大核(收益最大)

java 进程默认被锁在核心 0-4(小核),够不到大核。**开性能模式 + 重启 Tiny Container** 解锁:

```bash
# 重启容器 + 启动 MC 后检查亲和性
pgrep -f "java.*forge"
sudo taskset -pc <PID>
```

- `2-9` → 大核已解锁(tick 33ms)✅
- `0-4` → 重新开关性能模式或**完全退出并重开 Tiny Container**(注意:只重启 MC 实例无效,亲和性由容器启动时决定)

### 9.1 常规优化

```bash
# 1. 降视距(改 server.properties,面板里改或 SSH)
#    view-distance=6 / simulation-distance=4

# 2. 控制台预生成世界
#    chunky radius 2000
#    chunky start

# 3. 删 ARM 上失效的 AllTheLeaks(仅当你的 mods 里有这个 mod)
rm "/opt/mcsmanager/daemon/data/InstanceData/<实例UUID>/server/mods/"*alltheleaks*.jar
```

## 十、常见问题排查

| 现象 | 原因 | 解决 |
|---|---|---|
| `ssh: Connection refused` | sshd 没跑 / 容器重启过 | `bash /usr/local/bin/start-services.sh` 或 `/usr/sbin/sshd` |
| `scp: Connection closed` | proot SFTP 子系统失效 | 加 `-O` 参数强制 SCP 协议 |
| 面板打不开 23333 | MCSManager 没启动 | 跑第四节的 daemon + web 两条 nohup |
| 朋友连不上 MC | frp 断了 / 服务器没开 | `pgrep -f "frpc -f"` 查隧道;面板启动实例 |
| 朋友连不上但隧道在跑 | 本地 25565 没服务在听 | 确认 MC 实例已启动(`Done`) |
| TPS 低(<15) | 区块生成 / mod 事件 | 降视距 + chunky 预生成 |
| 面板/spark 显示 CPU 0% | proot 读不到真实 CPU | 正常现象,看 TPS 为准 |
| 服务器崩溃(watchdog 强杀,`A single server tick took 60s`) | 多为 chunky 踩中 mod 生成 bug | 见 9.3 教训;**恢复流程**:① 面板重启实例 ② 查亲和性(`taskset -pc` 应 2-9,否则完全退出重开容器)③ `pgrep` 确认全家桶 ④ 进游戏验证世界完好 ⑤ 确认正常后备份世界 |
| 日志刷 `Hanging entity at invalid position` / `Empty height range` | mod 生成器 bug 区域 | **立即 `chunky cancel`**,放弃该区域预生成 |

## 十一、系统地址速查

| 服务 | 地址/端口 |
|---|---|
| SSH | `<平板IP>:8022` |
| MCSManager 面板 | `http://<平板IP>:23333` |
| MC 服务器(局域网) | `<平板IP>:25565` |
| MC 服务器(公网/frp) | `<frp公网地址>` |
| frp 隧道日志 | `/tmp/frp.log` |
| VNC 远程桌面 | `<平板IP>:5901`(见十五节,可选) |

## 十二、硬件与核心速查(玄戒O1 阉割版)

| 集群 | 频率 | 核心(悬浮监测器) |
|---|---|---|
| 大核 X925 | 3.59 GHz | 核心 9/10 |
| 中核 A725 | 3.04 GHz | 核心 5/6/7/8 |
| 能效中核 | 1.89 GHz | 核心 3/4 |
| 小核 A520 | 1.79 GHz | 核心 1/2 |

**大核解锁检查(每次重启后必查)**:

```bash
pgrep -f "java.*forge"
sudo taskset -pc <PID>
```
- `2-9` → 大核已解锁(tick ~33ms)✅
- `0-4` → 大核锁死,重开性能模式或重启容器

> proot 里 taskset 改不动亲和性,只能靠"性能模式+重启"解锁;单核 GB6 2628 ≈ i5-13600K/i7-13700K。

## 十三、spark 实测性能速查(剑与王国 272 mod)

| 场景 | 亲和性 | Tick 中位 | TPS |
|---|---|---|---|
| 空载(锁核) | 0-4 | 45 ms | 20 |
| 2 人在线(锁核,区块生成高峰) | 0-4 | — | 7–10 |
| 空载(大核解锁) | 2-9 | **33 ms** | 20 |
| 有玩家/殖民地活动(解锁) | 2-9 | 39 ms | 20 |

**健康参考**:堆 1.3/4G(33%)、G1 Old GC 0 次 → 内存/GC 无瓶颈;瓶颈是主线程 tick(区块生成/mod 事件)。
**判读**:Tick 中位 <40ms = 健康;40–50ms = 紧张,做减负;>50ms = TPS 开始掉。

## 十四、世界备份与安全(必读)

> 世界是唯一副本,建议每周备份。**改 mod/升级前必须备份**。

```powershell
# Windows PowerShell:从平板拉取 world 备份
# (先停服/面板 stop,再在平板 SSH 里打包)
scp -O -P 8022 root@<平板IP>:/root/world-backup.tar.gz "D:\MC备份\"
```

或面板"文件"页直接压缩下载 `world` 文件夹。

**安全**:
- 樱花访问密钥泄露过就立即重置(natfrp.com),更新 `start-services.sh`
- 发布教程前:IP/密钥/隧道ID/实例UUID 全部换占位符

**清理**:`rm /root/mcserver.tar.gz`(6.2G 迁移包);定期清 `logs/`、`crash-reports/`

## 十五、VNC 远程桌面(可选)

```bash
sudo apt install -y tigervnc-standalone-server
which xfce4-session || sudo apt install -y xfce4-session
vncpasswd                                     # 设远程密码
mkdir -p /root/.vnc
printf '#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nxfce4-session &\n' > /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
vncserver :1 -geometry 1600x1000 -depth 24  # 启动,端口 5901
```

Windows 用 VNC Viewer 连 `<平板IP>:5901`。黑屏就补装 `xfce4-session xfce4-terminal` 再重启 VNC。proot 软件渲染,流畅度一般。
