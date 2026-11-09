# HClash · Native HarmonyOS Clash Client

[中文文档](README.md) | **English**

**HClash** is a native **HarmonyOS NEXT** (ArkTS + Rust) Clash client aiming for
"minimal yet complete", feature-comparable with [Clash Meta (mihomo)](https://github.com/MetaCubeX/mihomo)
and [Clash Verge](https://github.com/clash-verge-rev/clash-verge-rev).

> Status: v1.0.0 source complete and buildable. AppGallery publishing is deferred (see [ROADMAP](ROADMAP.md)).

## Highlights

- **Engine**: [clash-rs](https://github.com/Watfaq/clash-rs) (Rust), cross-compiled to
  `aarch64-unknown-linux-ohos` and bridged via NAPI. Protocols: Shadowsocks, VMess,
  VLESS, Trojan, Hysteria2, TUIC, SSH, Socks5, WireGuard, plus TLS/WS/gRPC/H2/REALITY
  transports and the full rule set (GEOIP/GEOSITE/domain/IP-CIDR/...).
- **UI**: Dashboard with live traffic chart and one-tap VPN connect; proxy groups with
  per-node latency tests; subscription manager (remote/local YAML, traffic & expiry
  info, auto-update); live connections; logs; rule browser; per-app proxy; settings.
- **System integration**: `VpnExtAbility` (vpn-type extension) owns the system tunnel;
  the TUN fd is fed to a userspace relay (clash-netstack + SOCKS5 to the local mixed
  port) — the same architecture as the official clash-rs iOS client.

## Build

```powershell
# 1) Build the Rust core (produces libs/libhclash_core_rust.a)
powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1   # Windows
./core/build-ohos.sh                                           # macOS / Linux

# 2) Open hclash/ in DevEco Studio 5.0+ (API 12+)
#    - Signing Configs: enable automatic signing with your Huawei account
# 3) Run on a real HarmonyOS NEXT device (VPN is not supported in the emulator)
```

See [BUILDING.md](BUILDING.md) for details and [ARCHITECTURE.md](ARCHITECTURE.md)
for the design.

## License

[GPL-3.0](LICENSE) © HClash Authors
