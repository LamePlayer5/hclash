# 架构设计（ARCHITECTURE）

## 1. 总体结构

HClash 由三层组成，UI 与内核完全解耦：

| 层 | 技术 | 位置 | 职责 |
|----|------|------|------|
| 界面层 | ArkTS / ArkUI | `entry/src/main/ets/` | 五大 Tab + 子页、组件、状态管理 |
| 服务层 | ArkTS | `entry/src/main/ets/services/` | 订阅管理、设置持久化、VPN 生命周期、API 客户端 |
| 内核层 | Rust（clash-rs）+ C++（NAPI） | `core/`、`entry/src/main/cpp/` | 代理引擎、规则/策略/DNS、TUN 中继 |

## 2. 进程模型

```
┌─ UI 进程 ──────────────────────────┐      ┌─ :vpn 扩展进程 ─────────────────┐
│ EntryAbility                       │      │ VpnExtAbility (type: vpn)        │
│  ├ 5 个 Tab 视图                   │      │  ├ vpnExtension.createVpn        │
│  ├ ApiClient ── HTTP/WS ───────┐   │      │  │   Connection() → tun fd      │
│  ├ ProfileManager（文件存储）   │   │      │  ├ CoreBridge (NAPI)            │
│  ├ SettingsStore（preferences） │   │      │  │   └ libhclash_core.so        │
│  └ VpnService                   │   │      │  │      └ clash-rs 引擎          │
└───────────────┬─────────────────┘   │      │  │      └ tun_relay             │
                │                     │      │  └ 系统 VPN 隧道                │
                └───── 127.0.0.1:9090 External Controller (mihomo 兼容 API) ───┘
```

- **UI 进程**不直接接触内核；启动/停止 VPN 通过 `vpnExtension.startVpnExtensionAbility`
  系统调用，由系统拉起 `:vpn` 进程
- **内核进程**在 `VpnExtAbility.onCreate` 中：读取 UI 写入的 `runtime.json`
  → 建立 VPN 隧道 → 取得 tun fd → NAPI 启动 clash-rs（配置注入 external-controller）
- UI 通过 RESTful API（`/version /configs /proxies /rules /connections`）与
  WebSocket（`/traffic /logs`）读写内核，与 mihomo 的 External Controller 完全兼容
  ——这意味着未来可无缝替换成 mihomo 内核

## 3. 内核层设计（core/）

### 3.1 引擎（engine.rs）
与官方 `clash-ffi` 相同的启动入口：

```rust
clash_lib::start_scaffold(Options {
    config: Config::Str(patched_yaml),
    cwd: Some(home_dir),
    rt: Some(TokioRuntime::MultiThread),
    log_file: Some(...),
    config_path: None,
})
```

启动前由 `config.rs` 将 `external-controller: 127.0.0.1:<apiPort>`、
`log-level` 注入 YAML（其余配置原样保留）。

### 3.2 TUN 中继（tun_relay.rs）
系统 VPN 隧道 fd 无法直接被 clash-rs 消费（内核自开 TUN 设备），
因此采用 tun2socks 风格的用户态中继（与 clash-rs 官方 iOS 客户端同构）：

```
TUN fd ──read──► NetStack (smoltcp) ──TCP──► TcpListener.accept ──► SOCKS5 CONNECT ─► 127.0.0.1:mixed
TUN fd ◄─write─ NetStack ◄─────────UDP───── UdpSocket.recv     ◄── SOCKS5 UDP ASSOC ◄┘
```

- `watfaq-netstack`（clash-rs 仓库 clash-netstack 目录）：官方用户态协议栈（smoltcp），负责 TCP 状态机、
  UDP 收发与 IP 包重组
- `socks5.rs`：RFC 1928 极简客户端（无认证），TCP 用 CONNECT、UDP 用 UDP ASSOCIATE
- 流量经 mixed 端口回到 clash-rs 引擎，完整经过规则/策略/出站协议处理

### 3.3 为什么这样设计
- **解耦**：UI 只认 mihomo 兼容 API，内核可独立升级/替换
- **可维护**：clash-rs 为上游活跃项目，协议更新只需重新交叉编译
- **同构验证**：watfaq-netstack 已被 clash-rs 官方 iOS 客户端（ChocLite）使用

## 4. 服务层设计

| 服务 | 持久化 | 职责 |
|------|--------|------|
| `ProfileManager` | `filesDir/profiles/`（meta.json + 每订阅一个 yaml） | 订阅下载（含 subscription-userinfo 解析）、本地导入、激活（复制为 active.yaml）、自动更新元数据 |
| `SettingsStore` | `preferences: hclash_settings` | 全部设置项、分应用代理 |
| `ApiClient` | — | External Controller 全量封装 + WebSocket（自动重连） |
| `VpnService` | `filesDir/runtime.json`（跨进程契约） | 生成运行时配置、启停扩展、状态轮询 |
| `TrafficSampler` | — | /traffic WS → AppState 速率/历史 |
| `AppState` | — | @Observed 全局状态单例 |

## 5. UI 层设计

- 单 Activity（EntryAbility）+ Tabs，五个视图组件 + 四个子页（router.pushUrl）
- 全局状态经 `@Observed AppState` 单例绑定；主题常量集中在 `theme/Theme.ets`
- 组件划分：StatCard / SectionHeader / EmptyState / TrafficChart /
  ProxyNodeItem / ProxyGroupCard

## 6. 安全与隐私

- External Controller 仅绑定 `127.0.0.1`，不暴露局域网；支持 secret（Bearer）
- 订阅下载 UA 使用 clash.meta 伪装（与 Clash Verge 一致），减少订阅商封锁
- 不采集、不上传任何用户数据；日志仅存本地 `filesDir/hclash-core.log`
