# 内嵌依赖：Watfaq/rustls 分叉

本目录是 [Watfaq/rustls](https://github.com/Watfaq/rustls) 分支 `watfaq/0.23.45`
（commit `63d10d5`）的**裁剪内嵌副本**，供 `core/Cargo.toml` 的 `[patch.crates-io]`
使用。

## 为什么内嵌

1. clash-rs 依赖该分叉的扩展 API（REALITY `RealityConfig`、ShadowTLS
   `connect_with_session_id_generator` 等），crates.io 的 rustls 没有这些 API；
2. 上游 `[patch]` 不会传递给依赖方，必须在本项目复刻；
3. 解析图中存在 `^0.23.46` 的要求（`noq` 等可选依赖链），分叉的 0.23.45 版本号
   无法统一整个依赖图，会与 registry 版并存导致编译失败。因此将版本号提升为
   **0.23.46**（`rustls/Cargo.toml`），使全部要求命中同一份分叉源码。

## 相对上游的改动

- `Cargo.toml`（workspace）：成员裁剪为仅 `rustls`；移除指向已删目录的
  `rustls-test` / `rustls-fuzzing-provider` 路径依赖
- `rustls/Cargo.toml`：`version` 0.23.45 → 0.23.46；移除 `[dev-dependencies]`
  与测试/基准 target 段（对应 `tests/`、`benches/`、`src/testdata/` 已删除）
- 其余源码与上游 commit `63d10d5` 一致，未做修改

## 许可证

Apache-2.0 OR ISC OR MIT（见 `LICENSE-APACHE`、`LICENSE-ISC`、`LICENSE-MIT`），
与上游一致。若上游发布 0.23.46+ 版本分叉，本目录应随之更新或改回 git 引用。
