# HClash · 原生鸿蒙 Clash 客户端

<p align="center">
  <img src="AppScope/resources/base/media/app_icon.png" width="128" alt="HClash logo">
</p>

**HClash** 是一款 **HarmonyOS NEXT 原生（ArkTS + Rust）** 的 Clash 客户端，
目标是"精简易用、功能齐全"，功能与体验对标 [Clash Meta (mihomo)](https://github.com/MetaCubeX/mihomo)
与 [Clash Verge](https://github.com/clash-verge-rev/clash-verge-rev)。

> **状态**：v1.0.0 源码已完成，可构建。华为应用商店上架暂不进行（见 [ROADMAP](ROADMAP.md)）。

---

## 功能特性

### 核心代理（内核 = clash-rs）
- 协议：**Shadowsocks / VMess / VLESS / Trojan / Hysteria2 / TUIC / SSH / Socks5 / Wireguard** 等
- 传输：TCP / TLS / WebSocket / gRPC / H2 / REALITY / QUIC / obfs 等
- 规则引擎：Domain / DomainSuffix / DomainKeyword / GEOIP / GEOSITE / IP-CIDR / Process 等全套规则类型
- 代理组：Selector / URLTest / Fallback / LoadBalance（手动切换、整组测速）
- 本地入口：mixed（HTTP+SOCKS5 同端口）/ http / socks5，可配 allow-lan

### 界面与交互（对标 Clash Verge）
| 页面 | 功能 |
|------|------|
| 首页 | 一键连接/断开、运行时长、当前配置、模式切换（规则/全局/直连）、实时流量曲线、上下行速率、活动连接数、内核版本 |
| 代理 | 代理组树、当前节点、逐节点延迟测试、整组/全部测速、点击切换节点 |
| 订阅 | 订阅添加/更新/编辑/删除、本地 YAML 导入、订阅流量与到期信息（subscription-userinfo）、自动更新间隔 |
| 连接 | 实时连接列表（目标/链路/规则/协议/流量/时长）、单条关闭、一键关闭全部、流量统计 |
| 设置 | 运行模式、混合端口、延迟测试 URL、MTU、DNS、IPv6、绕过私网、分应用代理、日志级别、API 端口/密钥、GEO 数据更新、自动连接 |
| 规则页 | 完整规则列表 + 搜索过滤 |
| 日志页 | 实时内核日志（error/warning/info/debug 分级、暂停/清空） |
| 分应用代理 | 白名单/黑名单两种模式，按应用选择代理或排除 |

### 系统集成（HarmonyOS NEXT）
- **VPN 全局接管**：`VpnExtAbility`（vpn 类型扩展）建立系统隧道，TUN fd 交给内核用户态中继
  （watfaq-netstack，与 clash-rs 官方 iOS 客户端同构方案），全设备流量进入规则引擎
- **分应用代理**：基于系统 VPN 的 trustedApplications / blockedApplications
- 后台保活、自动连接（可选）、数据备份扩展

---

## 架构

```
┌────────────────────────────── HarmonyOS NEXT ──────────────────────────────┐
│                                                                            │
│  UI 进程 (ArkTS / ArkUI)                  VPN 扩展进程 (:vpn)               │
│  ┌───────────────────────┐               ┌──────────────────────────┐     │
│  │ pages/  views/        │               │ VpnExtAbility            │     │
│  │ components/           │               │  ├ 系统 VPN 隧道 (tun fd) │     │
│  │ services/             │  RESTful API  │  ├ CoreBridge (NAPI)      │     │
│  │  ├ ProfileManager     │◄─────────────►│  └ libhclash_core.so      │     │
│  │  ├ SettingsStore      │  127.0.0.1    │      └ libhclash_core_    │     │
│  │  ├ ApiClient ─────────┼── :9090 ──────┼──►      rust.a (Rust)     │     │
│  │  ├ VpnService         │               │        ├ clash-rs 引擎    │     │
│  │  └ TrafficSampler     │               │        └ tun_relay        │     │
│  └───────────────────────┘               │        (watfaq-netstack)  │     │
│                                          └──────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────────┘
```

- **UI ↔ 内核**：RESTful External Controller API（与 mihomo 兼容：`/proxies /rules
  /connections /configs /traffic(ws) /logs(ws)`），UI 与内核解耦
- **内核**：clash-rs（Rust），交叉编译为 `aarch64-unknown-linux-ohos` 静态库，
  经 NAPI 桥接加载；配置注入 `external-controller` 等运行参数
- **TUN 中继**：watfaq-netstack（smoltcp 用户态协议栈）+ SOCKS5 出站至本地 mixed 端口

详见 [ARCHITECTURE.md](ARCHITECTURE.md)。

---

## 快速开始

### 环境要求
- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+（HarmonyOS NEXT SDK，API 12+）
- Rust 工具链（[rustup.rs](https://rustup.rs)）— 用于构建内核
- 真机：HarmonyOS NEXT 设备（VPN 能力需真机验证；模拟器不支持 VPN）

### 构建步骤

```powershell
# 1) 构建 Rust 内核（生成 libs/libhclash_core_rust.a）
powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1     # Windows
./core/build-ohos.sh                                             # macOS / Linux

# 2) 用 DevEco Studio 打开 hclash/ 目录
#    - File > Project Structure > Signing Configs：登录华为账号，启用自动化签名
#    - （如需分应用代理）在签名配置中申请 ACL：ohos.permission.GET_INSTALLED_BUNDLE_LIST
# 3) 连接真机，Run ▶
```

详细说明与常见问题见 [BUILDING.md](BUILDING.md)。

### 使用
1. 首次启动 → 「订阅」页添加订阅链接（或粘贴本地 YAML 导入）
2. 「订阅」页点击 **启用** 选择配置
3. 回到「首页」点击 **连接**，允许系统 VPN 授权
4. 「代理」页可切换节点/测速；「设置」页可调模式与隧道参数

---

## 仓库结构

```
hclash/
├── AppScope/                  # 应用级配置与资源（bundleName: com.hclash.app）
├── entry/src/main/
│   ├── ets/
│   │   ├── pages/             # Index(Tab) + Rules/Logs/About/AppProxy 子页
│   │   ├── views/             # 首页/代理/订阅/连接/设置 五大视图
│   │   ├── components/        # StatCard/TrafficChart/ProxyGroupCard/...
│   │   ├── services/          # ApiClient/ProfileManager/VpnService/...
│   │   ├── models/            # ClashTypes/Profile/Settings
│   │   ├── vpnextension/      # VpnExtAbility + 隧道配置构建
│   │   └── theme/ utils/      # 主题与工具
│   └── cpp/                   # NAPI 桥接（libhclash_core.so）
├── core/                      # Rust 内核（clash-rs 封装 + TUN 中继）
├── libs/                      # Rust 交叉编译产物（git 忽略）
└── scripts/                   # 开发脚本（图标生成等）
```

---

## 路线图（摘要）

- [x] v1.0 完整 UI + 订阅管理 + 规则/连接/日志 + VPN 接管框架 + 内核桥接
- [ ] 内核增量更新（GeoIP/Geosite 自动更新、providers 定时刷新）
- [ ] 仪表盘历史流量图表、连接地图
- [ ] 浅色主题、多语言完善
- [ ] 小组件/快捷开关、备份同步
- [ ] 华为应用商店上架（**暂缓**）

完整计划见 [ROADMAP.md](ROADMAP.md)。

---

## 参考与致谢

- [Watfaq/clash-rs](https://github.com/Watfaq/clash-rs) — Rust Clash 内核（本项目内核层，GPL-3.0）
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) — Clash.Meta 内核（API 兼容参考）
- [clash-verge-rev/clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev) — 界面与交互参考

## License

[GPL-3.0](LICENSE) © HClash Authors

> 本项目仅供学习与技术交流，请遵守当地法律法规。
