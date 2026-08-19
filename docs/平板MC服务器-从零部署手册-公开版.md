# 平板 MC 服务器 - 完整部署操作手册

> **这套方案解决什么问题**:
> - 笔记本开服 + 本机玩 = 服务端和客户端**抢同一颗 CPU、同一份内存**,两边都卡;
> - 方案把服务端搬到**安卓平板**上独立运行,电脑**专职当客户端**(modpack、光影、画质全拉满);
> - 服务端、客户端各用各的设备,互不抢资源,整体体验最优。
>
> **适用对象**:
> - 有一台**安卓平板**(建议 12GB+ 内存、256GB+ 存储),专门当 MC 服务器 7×24 低功耗挂机;
> - 有一台 **Windows 电脑**,专职跑 Minecraft 客户端(自己玩用);
> - 已经有一个《剑与王国》Forge 1.20.1 modpack 服务端(在笔记本/电脑上跑过),想整个搬到平板上;
> - 需要**内网穿透**,让不在同一个 Wi-Fi 的朋友也能公网进服联机。
>
> **本文档基于 2026-08 实测环境**:小米平板 7S Pro(16GB+512GB, 玄戒O1)/ Tiny Container / Debian 13 proot / 272 mod 服务端。
> **完整复制粘贴每一步的命令,照着做即可复现。** 每步都有"预期结果"帮你判断是否做对了。
>
> **⚠️ 通用性说明(必读)**:
> - 这是一套**通用方案**,适用于任何 Forge 1.20.1(或其他 Java 版)modpack 服务端,**不限于《剑与王国》**;
> - 文中出现的**具体路径/名称/数值**——`D:\学习版游戏`、`[服务端]1.20.1-剑与王国-1.19-Forge`、`272 mod`、`-Xms8G`、隧道 ID、实例 UUID、殖民地坐标等——**都是本机实测值,复现时全部替换为你自己的实际值**;
> - **如果你的服务端已经在 Windows/笔记本上跑过一段时间**(不是全新服务端),迁移的是"已有世界 + 已有配置",请注意:
>   - `eula.txt` 通常已是 `eula=true`,无需再改;
>   - `user_jvm_args.txt` 的内存值**可能改过、不一定是 8G**——调内存前先 `grep -E "Xm[sx]" user_jvm_args.txt` 看实际值(见阶段 6.2);
>   - 首次启动会**直接加载现有 world**,不是生成新世界,启动时间取决于世界大小;
>   - 你的 `mods/` 目录**可能与原整合包不同**(自己加过/删过 mod)——mod 数量、启动日志、AllTheLeaks 等判断**以你的实际 mod 集为准**;
> - 阶段 9 中 AllTheLeaks、chunky 生成 bug 等结论**只针对本文档实测的 modpack**,你的包不一定遇到,是否处理以日志为准。

---

## 目录

- 阶段 0:准备清单
- 阶段 1:安装容器环境(Tiny Container)
- 阶段 1.5:系统权限设置(必做)
- 阶段 2:SSH 远程控制打通
- 阶段 3:安装 MCSManager 面板
- 阶段 4:樱花 frp 公网穿透
- 阶段 5:迁移 MC 服务端
- 阶段 6:安装 Java 17 + 调整内存
- 阶段 7:首次启动 MC 服务端
- 阶段 8:把服务端托管进 MCSManager
- 阶段 9:性能调优
- 阶段 10:全自动启动整合
- 附录 A:日常运维速查
- 附录 B:故障排查表
- 附录 C:玄戒O1 硬件规格与性能实测

---

## 阶段 0:准备清单

开始前,确认以下条件全部满足:

| # | 项目 | 要求 | 说明 |
|---|---|---|---|
| 1 | 安卓平板 | 12GB+ 内存,256GB+ 存储 | 本手册按 16GB+512GB 编写,内存小的需把服务端堆调小 |
| 2 | Windows 电脑 | Win10/11 | 自带 `ssh`、`scp`、`tar` 命令,无需额外安装 |
| 3 | 服务端文件 | 笔记本上有 Forge 1.20.1 服务端文件夹 | 含 `mods/`、`world/`、`libraries/` 等完整目录 |
| 4 | 樱花 frp 账号 | https://www.natfrp.com/ 注册 | 免费,每日签到送流量 |
| 5 | 平板访问密钥 | natfrp.com 用户中心"访问密钥" | 一长串字符,后面 frp 要用 |
| 6 | 同一 Wi-Fi | 平板和电脑连同一个路由器 | 仅部署阶段需要,之后公网走 frp |

> ⚠️ **部署前必读:这套系统有三个"先天限制",会反复遇到**
>
> 1. **proot 容器不能绑定 1024 以下端口**(22/80 等),所以 SSH 用 **8022**、MC 用 25565(高位不受限)
> 2. **容器内 `ip`、`hostname -I` 命令不可用**(netlink 被 proot 拦截),查 IP 一律去安卓设置
> 3. **scp 传文件必须加 `-O` 参数**(proot 下 SSH 的 SFTP 通道失效)
>
> 记住这三点,下面就不会慌。

---

## 阶段 1:安装容器环境(Tiny Container)

Tiny Container 是一个安卓 App,让你在平板上直接跑一个带桌面(图形界面)的 Debian Linux 容器,全程不需要 root。

### 1.1 下载安装

1. 打开 https://github.com/Cateners/tiny_container/releases
2. 下载最新的 `.apk` 文件(找文件名类似 `tiny_container-vX.X.X.apk`)
3. 传到平板上(浏览器直接下载或微信/网盘),点击安装
   - 若提示"未知来源",到 设置 → 安全 → 允许安装未知应用 开启
4. 打开 **Tiny Container**

**预期结果**:首次打开会显示初始化进度(约 5 分钟),结束后直接进入 Debian 13 桌面(Xfce 图形界面)。

### 1.2 打开终端

桌面上找到 **终端 / Terminal** 图标并打开。

**预期结果**:看到一个命令行窗口,提示符类似:
```
tiny@localhost:~$
```
当前用户是 `tiny`(**不是 root**),后面所有需要管理员权限的命令都要加 `sudo`。

### 1.3 更新系统

```bash
sudo apt update && sudo apt upgrade -y
```
(提示密码就直接回车;中途问 `[Y/n]` 一律按 `y`)

---

## 阶段 1.5:系统权限设置(必做,不做后面全崩)

在**安卓系统设置**里给 Tiny Container 授权,这是容器和里面所有服务能"活着"的前提。

### 1.5.1 存储/文件权限

- 首次打开 Tiny Container 时会弹窗请求"文件与媒体"权限 → 点**允许**
- 如果当时跳过了:设置 → 应用管理 → Tiny Container → 权限 → **文件与媒体 → 允许**

> 容器内安卓存储挂载在 `/mnt/sdcard`,没权限会导致容器内读写异常。

### 1.5.2 后台运行权限(最关键)

锁屏/切后台时,安卓会杀掉"不听话"的 App。必须放行 Tiny Container:

- 设置 → 应用管理 → Tiny Container → **省电策略 → 无限制**
- 如有"自启动"选项 → 允许自启动
- 如有"后台弹出界面"权限 → 允许

**验证方法**:设置完后,打开 Tiny Container 的终端跑一个长任务(如 `sleep 300`),锁屏 5 分钟再打开,进程应该还在。

### 1.5.3 子线程/后台进程限制(关键)

安卓开发者选项默认会**限制后台子进程数**,而 proot 容器会派生大量子进程(sshd / frpc / node / java 等),不处理的话服务会被系统悄悄终止——表现为"服务莫名消失、面板打不开、查进程找不到"。

**必须操作:**

1. **开启开发者选项**(一次性):设置 → 我的设备 → 全部参数 → **连点"版本号"7 次**
2. 设置 → 更多设置 → 开发者选项 → 找到 **"限制后台进程"/"停止限制子进程"** → 设为 **"标准"**
   (不要选"不超过 1/2/3/4 个进程",否则 proot 子进程被砍)
3. 如存在,关闭 **"不保留活动"**(Don't keep activities)
4. 小米系系统额外确认:开发者选项里如有关闭 **"MIUI 优化"** 的开关,可关闭

> 设置路径在不同系统略有差异,关键词是 **"限制后台进程"** 或 **"停止限制子进程"**,把限制设为**标准/不限制**即可。
> 原则:让 Tiny Container 在后台自由派生进程,不被杀、不限制子进程数。

---

## 阶段 2:SSH 远程控制打通

目标:以后在 Windows 上直接远程操作平板容器,不用每次都碰平板。

### 2.1 容器内安装 SSH

在平板容器的终端里执行:

```bash
sudo apt install -y openssh-server
```

### 2.2 设置 root 密码(SSH 登录用)

```bash
sudo passwd root
```
输入两次你要用的密码(记住它)。

### 2.3 配置 SSH(端口 + 允许 root)

```bash
sudo sh -c 'echo "Port 8022" >> /etc/ssh/sshd_config'
sudo sh -c 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config'
sudo mkdir -p /run/sshd
```

> 端口必须是 **8022** 而不是 22——proot 绑定不了 22,直接用 22 会报 `Permission denied`。

### 2.4 启动 SSH

```bash
sudo /usr/sbin/sshd
```

**预期结果**:没有任何报错、直接回到提示符 = 成功。

### 2.5 查平板 IP

**安卓设置 → Wi-Fi → 当前连接的网络 → IP 地址**
(记下来,比如 `<平板IP>`。下面用 `<平板IP>` 代替)

### 2.6 Windows 上测试连接

按 `Win+R` → 输入 `cmd` → 回车,在命令窗口输入:

```powershell
ssh root@<平板IP> -p 8022
```

- 第一次连接会问 `Are you sure...` → 输入 `yes`
- 输入刚才设置的 root 密码

**预期结果**:看到 `root@localhost:~#` 提示符 = 远程打通。

---

## 阶段 3:安装 MCSManager 面板

MCSManager 是一个网页管理面板,装好后用浏览器就能启停 MC 服务器、看日志、传文件,不用碰命令行。

### 3.1 安装(SSH 会话里执行)

```bash
sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"
```

安装脚本会输出一段说明,结尾会提示用 `systemctl` 启动——**忽略 systemctl 部分**(proot 没有 systemd,用不了)。

### 3.2 挂载 node 命令

```bash
sudo ln -s /opt/mcsmanager/node-v20.12.2-linux-arm64/bin/node /usr/local/bin/node
sudo ln -s /opt/mcsmanager/node-v20.12.2-linux-arm64/bin/npm /usr/local/bin/npm
node -v    # 应显示 v20.x
```

### 3.3 手动启动面板(两个进程)

```bash
cd /opt/mcsmanager/daemon && sudo nohup node app.js > /tmp/daemon.log 2>&1 &
cd /opt/mcsmanager/web && sudo nohup node app.js > /tmp/web.log 2>&1 &
sleep 3
cat /tmp/daemon.log /tmp/web.log
```

**预期结果**:日志里出现监听 `24444`(daemon)和 `23333`(web)字样。

### 3.4 验证面板

Windows 浏览器打开:

```
http://<平板IP>:23333
```

**预期结果**:出现 MCSManager 登录/初始化页面,首次打开设置一个管理员账号密码。

---

## 阶段 4:樱花 frp 公网穿透

目的:让朋友从**任何网络**都能连进你的 MC 服务器。

### 4.1 注册账号 + 拿访问密钥

1. 打开 https://www.natfrp.com/ 注册登录
2. 登录后进入**用户中心**,找到**访问密钥**,点复制

### 4.2 容器内安装 frp 客户端

```bash
sudo bash -c ". <(curl -sSL https://doc.natfrp.com/launcher.sh)"
```

过程中:
- 提示"未发现 systemd,将只安装启动器文件" → 按回车继续
- 提示"请输入访问密钥" → 粘贴 4.1 复制的密钥,回车

**预期结果**:最后输出 `frpc 版本` 和 `natfrp-service 版本`,提示安装完成。

### 4.3 网页面板创建隧道

回到 natfrp.com → **隧道列表 → 创建隧道**,建两条:

| 隧道名 | 类型 | 本地IP | 本地端口 | 用途 |
|---|---|---|---|---|
| mc-server | TCP | `127.0.0.1` | `25565` | MC 服务器(朋友进服) |
| ssh-pad | TCP | `127.0.0.1` | `8022` | 外网远程管理(可选) |

> 免费版最多 2 条隧道,优先 mc-server;ssh-pad 需要时再建。

建完后,**在隧道列表记下每个隧道的 ID**(数字)。

### 4.4 直接启动隧道(不用交互式界面,适合保活)

```bash
sudo -u natfrp /home/natfrp/frpc -f 你的访问密钥:隧道ID1,隧道ID2 > /tmp/frp.log 2>&1 &
sleep 3
cat /tmp/frp.log
```

**预期结果**:日志出现 `隧道启动成功` 和公网地址(如 `<frp公网地址>`)。把这个地址记下,这就是朋友进服的地址。

> 多条隧道必须在**同一节点**才能用逗号分隔;不同节点就分开跑(每条一个 `-f`)。

---

## 阶段 5:迁移 MC 服务端

把笔记本上的服务端整个搬到平板。

### 5.1 笔记本:正常停服(关键!)

在笔记本的服务器控制台输入:

```
stop
```
**必须等服务器完全退出**,world 文件夹不能热拷,否则存档损坏。

### 5.2 笔记本:打包

在 Windows **PowerShell** 里执行(**路径换成你的实际服务端位置**):

```powershell
cd "D:\你的服务端上级目录"
tar -czf mcserver.tar.gz "你的服务端文件夹名"
```

**预期结果**:命令窗口卡住一段时间(几 GB 打包要几分钟),完成后回到提示符,文件夹里出现 `mcserver.tar.gz`。

### 5.3 笔记本 → 平板传输

```powershell
scp -O -P 8022 "D:\学习版游戏\mcserver.tar.gz" root@<平板IP>:/root/
```

> **`-O` 必须加!** proot 下 SSH 的 SFTP 通道失效,不加会报 `Connection closed`。
> `-P` 是大写 P(传输端口)。

**预期结果**:进度条走到 100%,回到提示符。

### 5.4 平板:解包

SSH 会话里:

```bash
mkdir -p /opt/mcserver
tar -xzf /root/mcserver.tar.gz -C /opt/mcserver
cd "<服务端目录>"
ls
```

**预期结果**:看到 `mods`、`world`、`libraries`、`config`、`eula.txt`、`run.sh` 等文件。

---

## 阶段 6:安装 Java 17 + 调整内存

### 6.1 为什么不用 `apt install` 装

Debian 13 软件源里**没有 openjdk-17**(只有 21),而 Forge 1.20.1 必须 Java 17。所以手动装 Eclipse Temurin 17(ARM 版,清华镜像)。

```bash
wget -O /tmp/java17.tar.gz "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jre/aarch64/linux/OpenJDK17U-jre_aarch64_linux_hotspot_17.0.20_8.tar.gz"
mkdir -p /opt/java17
tar -xzf /tmp/java17.tar.gz -C /opt/java17 --strip-components=1
sudo ln -sf /opt/java17/bin/java /usr/local/bin/java
java -version
```

**预期结果**:`openjdk version "17.0.20"`。

> GitHub 直连下载国内不稳(SSL 断连),所以用清华镜像。

### 6.2 调整内存(降到平板能承受的值)

**先看当前实际配置(你的包可能改过,不一定是 8G):**

```bash
grep -E "Xm[sx]" user_jvm_args.txt
```

如果输出 `-Xms8G -Xmx8G`(笔记本 32G 内存的配置),平板 16G 必须降,执行:

```bash
sed -i 's/-Xms8G/-Xms4G/; s/-Xmx8G/-Xmx4G/' user_jvm_args.txt
grep -E "Xm[sx]" user_jvm_args.txt
```

**预期结果**:输出 `-Xms4G` 和 `-Xmx4G`。

> 平板 12–16G 内存推荐 `-Xmx4G`(经实测 272 mod 堆只用 2.3G,4G 富余);如果原值本来就 ≤4G,不用改。

---

## 阶段 7:首次启动 MC 服务端

### 7.1 前台启动(先看有没有报错)

```bash
java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.20/unix_args.txt nogui
```

### 7.2 判断结果

| 现象 | 含义 |
|---|---|
| 日志滚动 5–10 分钟(mod 数量多,proot 下慢) | 正常,别急(具体时间看你的 mod 数) |
| 出现 `Done (xx.xxxs)!` + `>` 提示符 | ✅ 启动成功 |
| `java.lang.ExceptionInInitializerError`(AllTheLeaks) | ⚠️ 无害,ARM 兼容问题,可后续删该 mod(**仅当你的包里有它**) |
| `UnsatisfiedLinkError` | 🔴 JNI mod 不兼容 ARM,需要移除对应 mod |
| 10 分钟无动静 | 可能卡在联网检测,`Ctrl+C` 后加 `-Dfml.queryResult=confirm` 重试 |

> 首次进世界加载 `world` 文件夹(几 GB)是最慢的一步,耐心等。

### 7.3 验证服务器活着

在 `>` 后输入:

```
list
```
返回 `There are 0/20 players online` 即正常。

---

## 阶段 8:把服务端托管进 MCSManager(推荐)

托管后,以后在浏览器面板一键启停,不用碰终端。

### 8.1 创建实例

面板(23333)→ **实例列表 → 创建实例**:
- 名称:`剑与王国`
- 类型:Java Edition Minecraft
- 创建后记下进入实例详情

### 8.2 搬服务端文件进实例目录

SSH 执行:

```bash
ls /opt/mcsmanager/daemon/data/InstanceData/
```
(记录输出中的 UUID,如 `<实例UUID>`)

```bash
mkdir -p "/opt/mcsmanager/daemon/data/InstanceData/<UUID>/server"
mv "<服务端目录>"/* "/opt/mcsmanager/daemon/data/InstanceData/<UUID>/server/"
ls "/opt/mcsmanager/daemon/data/InstanceData/<UUID>/server/" | head
```

**预期结果**:server 目录里出现 mods、world 等文件(同文件系统,mv 是瞬时完成的)。

### 8.3 配置启动命令

面板 → 实例 → **启动配置 / 设置**:

- **启动命令**:
  ```
  /opt/java17/bin/java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.20/unix_args.txt nogui
  ```
- **工作目录**(如有):
  ```
  /opt/mcsmanager/daemon/data/InstanceData/<UUID>/server
  ```

### 8.4 启动

点**启动**,面板控制台滚动 Forge 日志 → `Done` 后进游戏测试。

---

## 阶段 9:性能调优(2 人以上掉 TPS 时做)

### 9.0 ⭐⭐⭐⭐ 解锁大核(收益最大,必做)

proot 容器的 java 进程默认被安卓 cpuset 锁在**核心 0-4(小核+能效核)**,够不到大核,单核性能被压 ~27%。

**解锁方法**:平板开**性能/游戏模式** + **重启 Tiny Container** → java 亲和性从 0-4 变 2-9(含大核 X925 3.59G)。

**验证**(每次重启容器 + 启动 MC 后都查一次):

```bash
pgrep -f "java.*forge"        # 拿 PID
sudo taskset -pc <PID>        # 确认是 2-9,不是 0-4
```

- 显示 `2-9` → 大核已解锁,spark tick 中位应 ~33ms(锁核时 ~45ms)
- 显示 `0-4` → 重新开关一次性能模式或再重启容器

> ⚠️ `taskset` 在 proot 里**改不动亲和性**(报"无效的参数"),只能靠"性能模式+重启"解锁。

**⚠️ 亲和性回退规律(重要)**:亲和性由**容器启动时**决定,不是 MC 实例启动时——所以:
- **只重启 MC 实例(面板重启)→ 亲和性仍是 0-4**,大核依然锁死
- 必须**完全退出 Tiny Container(后台划掉)→ 重新打开** → 亲和性才会回到 2-9
- 崩溃报告里 `CPUs: 5` 正是亲和性 0-4 时的假象(java 只认到 5 个核)

### 9.1 常规优化

| 优先级 | 操作 | 怎么做 |
|---|---|---|
| ⭐⭐⭐ | 降视距 | 面板文件管理编辑 `server.properties`:`view-distance=6`、`simulation-distance=4`,重启 |
| ⭐⭐ | 预生成世界 | 面板控制台:`chunky radius 2000` → `chunky start`(后台预生成,玩家无感) |
| ⭐⭐ | 删 AllTheLeaks | 面板文件管理删 `mods/alltheleaks-*.jar`(**仅当你的包里有这个 mod**;ARM 上它反射失败,基本无效) |
| ⭐ | 关平板图形桌面 | 平板上退出 Tiny Container 的桌面会话,释放内存 |

**预期效果**:大核解锁后空载 tick ~33ms;再做常规优化,2–4 人更稳。

### 9.2 chunky 预生成实战要点

**完整命令:**

```
chunky center <x> <z>      # 设中心(默认 0,0,务必改成玩家活动区!)
chunky radius 2000         # 设范围
chunky start               # 开始
chunky pause / continue    # 暂停 / 继续
chunky cancel              # 取消(出问题时立即用)
chunky status              # 查看进度
```

**关键经验(实测):**

1. **必须指定 center**:默认以 0,0 为中心,可能完全覆盖不到玩家的基地/殖民地。示例:殖民地在 (-1170, -3401),就要 `chunky center -1170 -3401`。
2. **速度参考(别被"快"骗了)**:chunky 只生成**缺失的区块**,已探索过的区块会被快速跳过——实测第一次 0,0 中心 48 秒跑完 6.3 万区块,很可能是大部分区块早已存在;"快"不代表真实生成速度。真正的新区块生成在 mod 服上可能只有个位数 cps(实测殖民地区域 2–8 cps),新区域预生成要预留足够时间。
3. **生成 bug 风险 ⚠️**:某些 mod 生成器在特定坐标有 bug(表现为 `Empty height range`、`Hanging entity at invalid position`),chunky 一旦碰到:
   - 速率暴跌(1400 → 2 cps)、ETA 暴涨(几分钟 → 几小时)
   - 从多线程降级到主线程,`Can't keep up!` 卡顿数秒~十几秒
   - **立即 `chunky cancel` 止损**,放弃该区域或换 center/缩小半径重试
4. **磁盘占用**:几万区块 = 几个 GB,留意剩余空间。

> 预生成只解决"探索时区块生成卡顿";已探索/建造的区域不受影响,出 bug 的区域先放着,以后真探索到了再排查。

### 9.3 ⚠️ chunky 崩溃实录(血的教训,必读)

> 以下问题**仅针对本文档实测的 modpack**。你的包如果 mods 改动过,不一定遇到;但只要出现特征信号(见下),处理方式相同。

实测中,在殖民地区域(-1170, -3401)预生成时**触发了 mod 世界生成 bug,直接把服务器干崩**:

**崩溃过程(经典链条):**
1. 生成器产出无效坐标(`Empty height range: [-55 absolute--60 absolute]` / `Hanging entity at invalid position: BlockPos{y=-57}`)
2. chunky 速率暴跌(1400 → 2 cps),从多线程降级到主线程
3. 生成器往世界塞入海量计划方块 tick,崩溃报告显示 **`block_ticks: 1,809,670`(180 万个)** → 主线程被压死
4. 单 tick 卡到 **60 秒**(正常 <50ms)→ MC **ServerWatchdog 判定崩溃,强制关服**
5. 堆内存冲到 90%(640 个 LevelChunk 驻留未回收),AllTheLeaks 报泄漏

**结论/铁律:**
- ⛔ **殖民地区域(-1170, -3401)附近绝对不要跑 chunky**,该区域 mod 生成器有 bug,一碰就崩服务器
- ✅ **0,0 周边区域预生成是安全的**(已实测 6.3 万区块正常)
- ✅ **watchdog 强杀不损坏已保存的区块**——崩溃后重启,殖民地、0,0 区域、存档全部完好
- 遇到生成 bug 的特征信号:速率暴跌 + `Empty height range` / `Hanging entity` 刷屏 + ETA 无限拉长 → **立即 `chunky cancel`**,别犹豫

---

## 阶段 10:全自动启动整合

把 sshd + frp + MCSManager 全部写进一个脚本,打开容器就自动就绪。

### 10.1 写一键启动脚本

```bash
sudo tee /usr/local/bin/start-services.sh > /dev/null <<'EOF'
#!/bin/bash
# sshd
mkdir -p /run/sshd
pgrep -x sshd >/dev/null || /usr/sbin/sshd
# frp 内网穿透
pgrep -f "frpc -f" >/dev/null || sudo -u natfrp /home/natfrp/frpc -f 你的访问密钥:隧道ID >/tmp/frp.log 2>&1 &
# MCSManager
pgrep -f "mcsmanager/daemon/app.js" >/dev/null || (cd /opt/mcsmanager/daemon && nohup node app.js >/tmp/daemon.log 2>&1 &)
pgrep -f "mcsmanager/web/app.js" >/dev/null || (cd /opt/mcsmanager/web && nohup node app.js >/tmp/web.log 2>&1 &)
echo "[OK] sshd + frp + MCSManager 已就绪"
EOF
sudo chmod 755 /usr/local/bin/start-services.sh
```

### 10.2 tiny 用户免密 sudo + 登录自动拉起

```bash
echo 'tiny ALL=(ALL) NOPASSWD: /usr/local/bin/start-services.sh' | sudo tee /etc/sudoers.d/tiny
sudo chmod 440 /etc/sudoers.d/tiny
echo 'pgrep -x sshd >/dev/null || sudo -n bash /usr/local/bin/start-services.sh 2>/dev/null || true' >> ~/.bashrc
```

### 10.3 验证

重启 Tiny Container → 重新打开终端 → 应打印 `[OK] sshd + frp + MCSManager 已就绪`。

---

## 附录 A:日常运维速查

| 动作 | 操作 |
|---|---|
| 开机启动整套 | 打开 Tiny Container → 浏览器开面板 → 点实例启动 |
| Windows 远程 | `ssh root@<平板IP> -p 8022` |
| 面板 | `http://<平板IP>:23333` |
| 朋友进服 | 公网地址(如 `<frp公网地址>`) |
| 传文件 | `scp -O -P 8022 文件 root@<平板IP>:/root/` |
| 查 TPS | 面板控制台 `spark tps` |
| 停服 | 面板控制台 `stop` |
| 手动拉全套服务 | `bash /usr/local/bin/start-services.sh` |

## 附录 B:故障排查表

| 现象 | 原因 | 解决 |
|---|---|---|
| `ssh: Connection refused` | sshd 没跑/容器重启过 | `bash /usr/local/bin/start-services.sh` |
| `Bind to port 22 failed: Permission denied` | proot 禁 <1024 端口 | 用 8022(2.3 已配) |
| `scp: Connection closed` | SFTP 子系统失效 | 命令加 `-O` |
| `openjdk-17 没有可安装候选` | Debian 13 无 17 | 用 6.1 的 Temurin 方案 |
| `java: command not found` | Java 未装/PATH 未配 | 重跑 6.1,检查 `/opt/java17` |
| `Missing privilege separation directory` | /run/sshd 不存在 | `sudo mkdir -p /run/sshd` |
| systemctl 命令无效 | proot 无 systemd | 用 `nohup node app.js &` 手动启动 |
| spark/面板 CPU 显示 0% | proot 读不到 /proc/stat | 正常,以 TPS 为准 |
| TPS <15 | 区块生成/mod 事件 | 阶段 9 三项优化 |
| 锁屏后全部服务消失 | 后台权限没设 | 阶段 1.5.2 省电策略"无限制" |

---

## 附录 C:玄戒O1 硬件规格与性能实测

### C.1 玄戒O1 规格与三版本差异

玄戒O1 采用 **2+4+2+2 十核四丛集**架构:2×X925 超大核 + 4×A725 性能核 + 2×A725 能效核 + 2×A520 小核(台积电第二代 3nm,190 亿晶体管)。

**三个版本的频率与单核跑分(官方/实测交叉验证):**

| 设备 | X925 超大核 | A725 性能核 | 单核 GB6 |
|---|---|---|---|
| 小米 15S Pro(满血) | **3.9 GHz** | 3.4 GHz | ~3000 |
| 小米平板 7 Ultra(降频) | 3.7 GHz | 3.04 GHz | 2715–2718 |
| **小米平板 7S Pro(本手册)** | **官网标称 3.4 GHz / 芯片面板实测 3.59 GHz** | 3.04 GHz | 2628 |

> **7S Pro 频率说明**:小米官网规格页标注"X925 双超大核 **3.4 GHz** 最高主频",但平板系统内置的**"芯片性能面板"实测大核峰值 3.59 GHz**(悬浮监测器也记录到 3398 MHz ≈ 3.4G)。以实测为准:7S Pro 的 X925 实际 ≈ 3.59 GHz,仍比 15S Pro 满血版(3.9G)低约 8%。
>
> **关键认知**:所谓"阉割"不止 X925——**A725 性能核也从满血的 3.4 GHz 降到 3.04 GHz**(和 7 Ultra 一样)。这对 MC 服务器影响更大:调度器通常把主线程放在中核/大核,3.04 GHz 就是日常主力频率。
>
> 数据来源:小米官网规格页、IT之家(7 Ultra Geekbench 首曝)、小米系统"芯片性能面板"实测、Notebookcheck。

### C.2 7S Pro 实际频率(小米"芯片性能面板")

| 集群 | 频率 | 对应核心(悬浮监测器 1-based) |
|---|---|---|
| **大核 X925** | **3.59 GHz** | 核心 **9/10** |
| 中核 A725 | 3.04 GHz | 核心 5/6/7/8 |
| 能效中核 A725 | 1.89 GHz | 核心 3/4 |
| 小核 A520 | 1.79 GHz | 核心 1/2 |

### C.3 proot cpuset 限制与大核解锁(性能关键)

**问题**:proot 容器内 java 进程默认亲和性被锁在 **核心 0-4**(小核+能效核+1 中核),**够不到大核 X925**,单核性能被压约 27%。

**解锁方法**:平板开**性能/游戏模式** + **重启 Tiny Container** → java 亲和性变为 **2-9**,大核解锁。

**验证**(每次重启后检查):
```bash
pgrep -f "java.*forge"
sudo taskset -pc <PID>     # 应为 2-9;若 0-4 则重开性能模式或再重启
```

> ⚠️ taskset 在 proot 里**改不动亲和性**(报"无效的参数"),只能靠"性能模式+重启"解锁。

### C.4 实测性能数据(剑与王国 272 mod)

**spark tps 实测(2026-08,小米平板 7S Pro):**

| 场景 | 亲和性 | Tick 中位 | Tick 95%ile | TPS |
|---|---|---|---|---|
| 空载(大核锁死) | 0-4 | 45 ms | 77 ms | 20 |
| 2 人同时在线(锁核,区块生成高峰) | 0-4 | — | — | **7–10** |
| 空载(**大核解锁**) | 2-9 | **33 ms** | 45 ms | 20 |
| 有玩家/殖民地在活动(解锁) | 2-9 | 39 ms | 60 ms | 20 |

**spark health 报告(堆/GC/内存):**

| 指标 | 实测值 | 结论 |
|---|---|---|
| JVM 堆 | 1.3 GB / 4 GB(33%) | 堆完全够,**GC 不是瓶颈** |
| G1 Young GC | 平均 43 ms,频率 ~1m19s | 正常 |
| G1 Old GC | **0 次** | 无老年代压力 |
| 物理内存 | 11.8 / 15.2 GB(77%) | 偏紧(系统+桌面+各服务共存) |
| Swap | 5.3 GB | 有交换,未致命 |

**性能结论:**
- 空载 TPS 满 20;大核解锁后 tick 中位 33ms(锁核时 45ms)
- 2 人活动掉到 7–10 TPS 是**优化前(锁核)**的数据;解锁后预计能稳 2–3 人
- 瓶颈是**主线程 tick**(区块生成/mod 事件),不是内存/GC
- 堆内存参考:笔记本实测同包只用 2.3G,平板 -Xmx4G 合理
- 单核 GB6 2628 ≈ i5-13600K / i7-13700K 级别(非满血版 i9 级)
- **不要锁大核**:java 是多线程(主线程+GC+工作线程),只绑 2 个核心反而互相抢占;保持 2-9 自由调度最优

---

## 附录 D:世界备份与安全(必读)

> **你的世界(殖民地 + 建筑)是唯一副本,没有任何云备份——一旦平板损坏/容器误删/文件损坏,几年的心血直接没了。备份是比性能优化更重要的事。**

### D.1 一键备份世界(推荐:每周做一次)

在 Windows PowerShell 执行(平板 IP 换成你的):

```powershell
# 停服后再备份(防止热拷损坏)。面板控制台 stop,或临时停实例
# 平板端打包 world(在 SSH 会话执行):
#   cd "/opt/mcsmanager/daemon/data/InstanceData/<UUID>/server" && tar -czf /root/world-backup.tar.gz world

# Windows 拉取到本地(建议放移动硬盘/网盘同步目录)
scp -O -P 8022 root@<平板IP>:/root/world-backup.tar.gz "D:\MC备份\"
```

**预期结果**:本地出现 `world-backup.tar.gz`(大小看世界规模,几 GB 正常)。

> 更省事的做法:停服后直接在面板"文件"页把 `world` 文件夹**压缩下载**,无需命令行。

### D.2 备份频率建议

| 场景 | 建议 |
|---|---|
| 大规模建筑/殖民地扩张后 | 立即备份一次 |
| 日常 | 每周一次,或每周两次 |
| 修改 mod / 升级服务端前 | **必须先备份**(改 mod 失败可能损坏世界) |
| 崩溃/异常后 | 恢复运行确认正常后备份一次 |

### D.3 安全提醒 ⚠️

- **樱花 frp 访问密钥**等于你隧道的钥匙:泄露 = 别人能借用你的隧道和流量。**一旦不小心公开过(如截图、贴到聊天),立即去 https://www.natfrp.com/ 重置访问密钥**,然后更新 `/usr/local/bin/start-services.sh` 里的密钥。
- **root 密码 / 平板 IP** 不要公开。发布教程前把真实 IP、密钥、隧道 ID、实例 UUID 全部换成占位符(本手册公开版已做)。

### D.4 清理占用

- 迁移用的 `mcserver.tar.gz`(约 6.2G)解包后可以删:平板 SSH 里 `rm /root/mcserver.tar.gz`
- 服务器 `logs/` 和 `crash-reports/` 会累积,定期清理:`cd <服务端目录> && rm -rf logs/* crash-reports/*`
- chunky 预生成的区块也占磁盘,留意平板剩余空间(512G 够用,但别堆积)

---

## 附录 E:VNC 远程桌面(可选,需要图形界面时)

需要"在 Windows 上看到并操作平板 Linux 桌面"时用。纯命令行管理(SSH/面板)用不到它。

### E.1 安装 + 启动(SSH 会话)

```bash
# 装 VNC + 桌面
sudo apt install -y tigervnc-standalone-server
which xfce4-session || sudo apt install -y xfce4-session

# 设 VNC 密码(Windows 连接时用)
vncpasswd

# 配置桌面启动脚本
mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xfce4-session &
EOF
chmod +x /root/.vnc/xstartup

# 启动 VNC(虚拟桌面,端口 5901)
vncserver :1 -geometry 1600x1000 -depth 24
```

**预期结果**:输出 `New 'X' desktop is localhost:1`。

### E.2 Windows 连接

1. 下载 **VNC Viewer**(TigerVNC / RealVNC 免费版均可)
2. 地址填:`<平板IP>:5901`
3. 输入 E.1 设置的密码 → 看到 Xfce 桌面

### E.3 踩坑预案

- **黑屏/空白**:xfce4-session 没装全,执行 `sudo apt install -y xfce4-session xfce4-terminal` 后重启 VNC
- **连不上**:`vncserver -list` 确认桌面在跑;检查端口 5901 是否被防火墙拦
- **以后重启容器后要再开**:重新执行 `vncserver :1 -geometry 1600x1000 -depth 24`
- proot 软件渲染,远程桌面流畅度一般,够用但别期待丝滑

---

*本手册基于小米平板 7S Pro / Tiny Container / Debian 13 proot 实测编写。按阶段顺序执行即可完整复现。*
