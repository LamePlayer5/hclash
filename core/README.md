# HClash Core（Rust 内核桥接层）

该目录是 HClash 的原生内核层：将 [clash-rs](https://github.com/Watfaq/clash-rs)
（Rust 实现的 Clash 内核）交叉编译为 HarmonyOS NEXT（aarch64）静态库，
由 `entry/src/main/cpp/napi_init.cpp` 封装为 NAPI 模块 `libhclash_core.so`。

## 组成

| 文件 | 说明 |
|------|------|
| `src/lib.rs` | C ABI 入口：`hclash_start / hclash_stop / hclash_version` |
| `src/engine.rs` | clash-rs 引擎封装（与官方 clash-ffi 相同入口 `start_scaffold`） |
| `src/config.rs` | 配置注入（external-controller / log-level）与读取 |
| `src/tun_relay.rs` | TUN 中继：系统 VPN fd → clash-netstack 用户态栈 → SOCKS5 出站 |
| `src/socks5.rs` | 极简 SOCKS5 客户端（RFC 1928：CONNECT / UDP ASSOCIATE） |
| `build-ohos.ps1` / `build-ohos.sh` | 交叉编译脚本（生成 `libs/libhclash_core_rust.a`） |

## 构建

```powershell
# Windows（需 Rust + DevEco Studio SDK）
powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1

# macOS / Linux
./core/build-ohos.sh
```

然后在项目根目录用 DevEco Studio 或 `hvigorw assembleHap` 构建 HAP。

## 数据路径

```
[设备应用] ──► TUN fd（系统 VPN）──► clash-netstack（smoltcp 用户态栈）
                 │                       │
                 │                       ├─ TCP 流 ──► SOCKS5 CONNECT ──┐
                 │                       └─ UDP 报文 ─► SOCKS5 UDP ─────┤
                 │                                                     ▼
                 │                                   127.0.0.1:mixed-port
                 │                                                     │
                 │                                          clash-rs 引擎
                 │                                    （规则/策略/DNS/出站协议）
                 ▼                                                     │
             远端服务器 ◄──────────────────────────────────────────────┘
```

## 协议覆盖

内核为 clash-rs，编译启用 `shadowsocks / tuic / ssh / zero_copy`（与官方
clash-ffi 相同的 feature 组合），VMess / VLESS / Trojan / Hysteria2 / Shadowsocks /
TUIC / SSH / Socks5 / Wireguard 等核心协议与传输层（TLS / WS / gRPC / H2 /
REALITY 等）均由内核提供。TUN 全局接管通过本层的用户态中继实现（与
clash-rs 官方 iOS 客户端同构方案）。

## 说明

- 首次构建时如 clash-rs 上游 API 有变动（`start_scaffold`/`Options` 字段），
  只需同步调整 `engine.rs`（对齐官方 `clash-ffi/src/lib.rs`）。
- `config.rs` 与 `socks5.rs` 含单元测试：`cargo test`。
