# 平板 MC 服务器 — Android 平板托管 Java Mod 服完整方案

在安卓平板(Tiny Container / Termux proot)上跑 **Forge/Fabric Java 版 Minecraft 服务端**,配合 MCSManager 网页面板 + 樱花 frp 内网穿透,实现**远程管理 + 公网联机**的完整闭环。

> 本项目是**教程 + 脚本**仓库,不含任何 mod / 整合包文件(版权归原作者)。

## 这套方案解决什么问题

- 笔记本开服 + 本机玩 = 服务端和客户端**抢同一颗 CPU、同一份内存**,两边都卡;
- 方案把服务端搬到**安卓平板**上独立低功耗挂机,电脑**专职当客户端**(modpack、光影、画质全拉满);
- 服务端、客户端各用各的设备,互不抢资源,体验最优。

## 适用对象

- 有一台**安卓平板**(建议 12GB+ 内存、256GB+ 存储)当服务器;
- 有一台 **Windows 电脑**专职跑 Minecraft 客户端;
- **已经有一个在 Windows/笔记本上跑过的 Forge modpack 服务端**,想整体搬到平板(已有世界、已有配置);
- 需要**内网穿透**,让不在同一个 Wi-Fi 的朋友公网进服联机。

## 特性

- ✅ **完整迁移流程**:已有服务端(含世界存档)从 Windows 整体搬到平板的打包/传输/解包步骤,不停服不热拷
- ✅ **远程管理闭环**:SSH(远程终端)+ MCSManager(浏览器网页面板启停/看日志/传文件)+ 樱花 frp(公网穿透)
- ✅ **proot 坑全集**:1024 以下端口、netlink 受限、scp -O、Debian 无 Java 17、无 systemd、CPU 亲和性锁定……全部给出实测解法
- ✅ **性能优化实测**:大核解锁(CPU 亲和性)、chunky 预生成、降视距等,附 **spark 实测数据**
- ✅ **可复现**:每一步有操作说明 + 命令 + 预期结果 + 报错对照

## 快速开始

完整部署手册(从零到公网联机):**[docs/平板MC服务器-从零部署手册-公开版.md](docs/平板MC服务器-从零部署手册-公开版.md)**

日常运维指令速查:**[docs/平板MC服务器-指令手册-公开版.md](docs/平板MC服务器-指令手册-公开版.md)**

一键启动脚本模板(sshd + frp + MCSManager):**[scripts/start-services.sh](scripts/start-services.sh)**

## 目录结构

```
plate-mc-server/
├── README.md                          # 本文件
├── docs/
│   ├── 平板MC服务器-从零部署手册-公开版.md   # 完整部署手册
│   └── 平板MC服务器-指令手册-公开版.md      # 日常运维速查
└── scripts/
    └── start-services.sh              # 一键启动脚本(占位符版)
```

## 实测环境

| 项目 | 配置 |
|---|---|
| 平板 | 小米平板 7S Pro(16GB+512GB, 玄戒O1) |
| 容器 | Tiny Container(Debian 13, proot) |
| 服务端 | Forge 1.20.1 + 272 mod(剑与王国整合包) |
| 面板 | MCSManager |
| 穿透 | 樱花 frp |

## 已知问题 / 注意事项

- **proot 环境限制**:不能绑定 <1024 端口(SSH 用 8022)、netlink 受限(ip/hostname 不可用)、无 systemd、Java 需手动装 Temurin 17
- **CPU 亲和性**:容器内 java 进程默认被锁在小核,需要"性能模式 + 重启容器"解锁大核(详见部署手册附录 C)
- **chunky 生成 bug**:部分 mod 生成器在特定坐标有 bug,chunky 预生成可能触发(详见部署手册阶段 9)
- **mod 兼容性**:部分 JNI mod 在 ARM 上不兼容,以实际日志为准

## 免责声明

- 本项目仅包含教程与脚本,**不包含任何 mod / 整合包 / 世界存档文件**,请自行准备并遵守各 mod 的许可证;
- 教程中的 IP、密钥、隧道 ID、实例 UUID 等均为占位符,请替换为你自己的值;
- 在 proot 环境下运行 Java 服务端存在性能损耗,大型整合包建议 4 人以内游玩。

## 许可证

[MIT](LICENSE)
