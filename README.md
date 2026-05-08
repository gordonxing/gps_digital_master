# 🚛 Fleet Master — 开箱即用的私有化车联网平台

> **一行命令，拥有你自己的 GPS 追踪 + 数字钥匙 + 车队管理平台。数据 100% 留在你的服务器。**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu)](https://ubuntu.com/)
[![Docker](https://img.shields.io/badge/Docker-24%2B-2496ED?logo=docker)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-Commercial-red)](LICENSE)

[English](#-fleet-master--one-click-self-hosted-vehicle-iot-platform) | [简体中文](#-fleet-master--开箱即用的私有化车联网平台)

---

📡 **GPS 实时追踪** · 🔑 **数字钥匙** · 🚨 **智能报警** · 📊 **Web 管理后台** · 📱 **微信小程序**

---

## 👀 这是你要找的吗？

如果你面临以下任何一个场景，**Fleet Master 就是为你准备的**：

- ✅ 你有 GPS 定位器 / OBD 设备，需要一个**属于自己的**追踪平台
- ✅ 你是车队/租赁公司老板，不想把车辆数据交给第三方 SaaS 平台
- ✅ 你在做数字钥匙硬件，需要配套的**管理后台 + 用户小程序**
- ✅ 你想要一个**完全私有化部署**的车联网系统，数据不出服务器
- ✅ 你在找一个可以**二次销售给客户**的成套软硬件方案

---

## ⚡ 为什么选 Fleet Master？

| 对比维度 | SaaS 平台 | 开源方案 | **Fleet Master** |
|---------|----------|---------|:---:|
| 数据所有权 | ❌ 平台手里 | ✅ 你的 | ✅ **你的** |
| 安装难度 | 注册即用 | ❌ 折腾数天 | ✅ **一行命令** |
| 源码保护 | - | ❌ 裸奔 | ✅ **.so 编译加密** |
| 永久免费 | ❌ 按月付费 | ✅ | ✅ **5 台设备免费** |
| 全套功能 | 追踪而已 | 拼凑组件 | ✅ **追踪+钥匙+报警+小程序** |
| 技术支持 | 客服工单 | ❌ Issue | ✅ **邮件+微信** |

---

## 🚀 3 分钟部署

```bash
git clone https://github.com/eyesoncar/iot-deploy.git
cd iot-deploy
sudo ./install.sh
```

**脚本自动完成**：系统检测 → Docker 安装 → 配置生成 → 拉镜像 → 初始化数据库 → 启动服务 → 健康检查。

> 🎉 **装完即用** — 打开浏览器访问 `http://你的服务器IP`，默认账号 `admin` / `admin123456`

<details>
<summary>📋 服务器要求（点击展开）</summary>

| 项目 | 最低配置 | 推荐配置 |
|------|---------|---------|
| 操作系统 | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| CPU | 4 核 | 8 核 |
| 内存 | 8 GB | 16 GB |
| 磁盘 | 100 GB SSD | 200 GB SSD |

</details>

---

## 🧩 功能全景

```
                                Fleet Master
        ┌──────────┬──────────┬──────────┬──────────┬──────────┐
        │  📡 GPS  │  🔑 数字  │  🚨 智能  │  📊 Web   │  📱 移动端  │
        │  实时追踪  │   钥匙   │   报警   │  管理后台  │  小程序    │
        ├──────────┼──────────┼──────────┼──────────┼──────────┤
 核心    │ 实时定位  │ 蓝牙钥匙  │ 围栏报警  │ 设备管理  │ 车辆控制  │
 功能    │ 轨迹回放  │ 远程开锁  │ 超速报警  │ 用户管理  │ 轨迹查看  │
        │ 电子围栏  │ 钥匙分享  │ 断电报警  │ 权限控制  │ 报警推送  │
        │ 多协议支持 │ 冻结/解冻 │ 位移报警  │ 报表统计  │ 在线充值  │
        └──────────┴──────────┴──────────┴──────────┴──────────┘
        ┌──────────────────────────────────────────────────────┐
        │              🔒 授权系统（5 台免费 · 按需扩容）          │
        │   RSA 签名防伪 · HMAC 防篡改 · 机器码绑定 · 买断制     │
        └──────────────────────────────────────────────────────┘
```

<details>
<summary>📡 支持的 GPS 协议（点击展开）</summary>

| 协议 | 适用设备 |
|------|---------|
| XCUDP / XCTCP | 信春 Q11 等（自研协议） |
| GT06 | 谷米、万通等 |
| H02 | 微途、沃天等 |
| JT808 | 部标设备、华宝等 |
| Teltonika | 国际品牌 |
| GPS103 | Google 协议 |
| TK103 | 拓步达等 |
| Meitrack | Meitrack 系列 |

</details>

---

## 🏗️ 系统架构

```
                    你的浏览器 / 微信小程序
                            │
                    ┌───────▼────────┐
                    │  OpenResty 网关  │  反向代理 + WAF 防护
                    └───┬─────────┬──┘
                        │         │
              ┌─────────▼──┐  ┌──▼──────────┐
              │  后端 API   │  │  前端管理后台  │
              │  FastAPI    │  │  Vue 3       │
              │  (.so 加密) │  │  (Nginx)     │
              └──┬────┬─────┘  └─────────────┘
                 │    │
      ┌──────────▼┐   │   ┌──────────────┐
      │ PostgreSQL │   │   │    Redis      │
      │ + PostGIS  │   │   │  缓存 / 队列   │
      └────────────┘   │   └──────────────┘
                       │
              ┌────────▼────────┐
              │    Traccar       │  GPS 协议引擎
              │  (私有协议插件)   │  设备数据上报 →
              └─────────────────┘
```

---

## 🔐 安全与授权

| 防护层 | 技术手段 |
|--------|---------|
| 源码保护 | Cython `.so` 编译，核心代码为机器码 |
| License 防伪 | RSA 2048 非对称加密签名 |
| 数据防篡改 | HMAC-SHA256 设备绑定签名流水 |
| 防 License 拷贝 | 机器码绑定，换服务器即失效 |
| 网络防护 | OpenResty + Lua WAF |

### 💰 免费额度

**安装即赠送 5 台设备永久免费额度**（GPS 和数字钥匙通用），无需 License。

需要更多设备？[联系我们](#-联系方式) 购买 License，买断制，永不过期，支持 50/100/500/不限量 灵活选择。

---

## 📦 deploy/ 目录说明

```
deploy/
├── docker-compose.yml    # 服务编排（一键启动全部服务）
├── install.sh            # 一键安装脚本
├── .env.template         # 环境配置模板
├── openresty/            # 网关配置（反向代理 + WAF + HTTPS）
├── sql/                  # 数据库初始化脚本
├── scripts/              # 工具脚本（机器码生成等）
├── license/              # 授权操作文档
├── docs/                 # 部署 & 配置文档
└── traccar/              # GPS 引擎配置
```

---

## 📮 联系方式

| 渠道 | 地址 |
|------|------|
| 📧 邮箱 | **support@eyesoncar.com** |
| 💬 微信 | **vmstms** |

> 💡 **需要 License 扩容？** 发送机器码 + 所需设备数量到邮箱或微信，当天签发交付。
>
> 💡 **硬件设备咨询？** 提供配套 GPS 定位器 (Q11) 和数字钥匙硬件，软硬件一体化方案。

---

<br>

# 🚛 Fleet Master — One-Click Self-Hosted Vehicle IoT Platform

> **One command to own your GPS tracking + digital key + fleet management platform. 100% data on your server.**

---

📡 **GPS Tracking** · 🔑 **Digital Key** · 🚨 **Smart Alerts** · 📊 **Web Admin** · 📱 **WeChat Mini Program**

---

## 👀 Is This What You Need?

- ✅ You have GPS trackers and want **your own** tracking platform — not someone else's SaaS
- ✅ You run a fleet / rental company and refuse to hand vehicle data to third parties
- ✅ You make digital key hardware and need a **management backend + user app**
- ✅ You want a **fully self-hosted** vehicle IoT system — data never leaves your server
- ✅ You're looking for a **resellable** hardware + software package for your customers

---

## ⚡ Why Fleet Master?

| | SaaS Platforms | Open Source | **Fleet Master** |
|---|:---:|:---:|:---:|
| Data Ownership | ❌ Their cloud | ✅ Yours | ✅ **Yours** |
| Setup Time | Sign up | ❌ Days of tinkering | ✅ **One command** |
| Source Protection | - | ❌ Exposed | ✅ **.so encrypted** |
| Free Forever | ❌ Monthly fees | ✅ | ✅ **5 devices free** |
| All-in-One | Tracking only | Piecemeal | ✅ **Track + Key + Alerts + App** |
| Support | Ticket queue | ❌ GitHub Issues | ✅ **Email + WeChat** |

---

## 🚀 Deploy in 3 Minutes

```bash
git clone https://github.com/eyesoncar/iot-deploy.git
cd iot-deploy
sudo ./install.sh
```

**The script handles everything**: OS check → Docker install → config generation → image pull → DB init → service start → health check.

> 🎉 **Done!** Open `http://your-server-ip` — default login: `admin` / `admin123456`

<details>
<summary>📋 Server Requirements</summary>

| Item | Minimum | Recommended |
|------|---------|-------------|
| OS | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 16 GB |
| Disk | 100 GB SSD | 200 GB SSD |

</details>

---

## 🔐 Security & Licensing

| Layer | Protection |
|-------|-----------|
| Source Code | Cython `.so` compilation — core logic is machine code |
| License Anti-Forgery | RSA 2048 asymmetric signature |
| Data Tamper-Proof | HMAC-SHA256 device binding audit trail |
| License Copy Protection | Machine ID binding — invalid on other servers |
| Network Defense | OpenResty + Lua WAF |

### 💰 Free Tier

**5 devices free forever** (GPS + digital key combined). No License required to start.

Need more? [Contact us](#-contact) for a License — one-time purchase, no expiry. 50/100/500/unlimited tiers available.

---

## 📮 Contact

| Channel | Address |
|---------|---------|
| 📧 Email | **support@eyesoncar.com** |
| 💬 WeChat | **vmstms** |

> 💡 **Need a License upgrade?** Send your Machine ID + device count — same-day delivery.
>
> 💡 **Hardware inquiries?** We offer Q11 GPS trackers and digital key hardware for a complete solution.

---

<p align="center">
  <sub>Made with ❤️ by EyesOnCar · <a href="LICENSE">Commercial License</a></sub>
</p>
