# 构建指南（BUILDING）

本文档说明如何从源码构建、运行与调试 HClash。

## 1. 环境准备

| 组件 | 版本 | 用途 |
|------|------|------|
| DevEco Studio | 5.0+ | 构建 HAP、签名、安装真机 |
| HarmonyOS NEXT SDK | API 12+（compileSdkVersion 12） | ArkTS/ArkUI 编译、NDK（CMake/clang） |
| Rust（rustup） | stable（1.80+） | 编译 clash-rs 内核为 ohos 静态库 |
| Python 3 | 3.9+（可选） | 仅开发脚本（图标生成） |
| 真机 | HarmonyOS NEXT | VPN 能力验证（模拟器不支持 VPN） |

DevEco Studio 安装时请勾选 **OpenHarmony SDK > Native**（含 CMake、clang、sysroot）。

## 2. 构建 Rust 内核

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1
# 可显式指定 SDK：
powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1 -SdkPath "C:\OpenHarmony\Sdk\12\native"
```

```bash
# macOS / Linux
./core/build-ohos.sh
# 或 OHOS_SDK_NATIVE=~/OpenHarmony/Sdk/12/native ./core/build-ohos.sh
```

脚本完成以下事项：
1. 自动探测 OHOS native 工具链（也可用环境变量 `OHOS_SDK_NATIVE` 指定）
2. `rustup target add aarch64-unknown-linux-ohos`
3. `cargo build --release --target aarch64-unknown-linux-ohos`（拉取 clash-rs 依赖）
4. 产出拷贝到 `libs/libhclash_core_rust.a`

> 首次构建需联网拉取 clash-rs 与其依赖，耗时约 5–15 分钟。

## 3. 构建 HAP

1. DevEco Studio 打开 `hclash/` 目录（首次会执行 ohpm install / hvigor 同步）
2. **签名**：`File > Project Structure > Signing Configs`
   - 登录华为开发者账号，勾选 *Automatically generate signature*（调试证书）
   - 如需 **分应用代理** 功能，需在签名时申请 ACL 权限
     `ohos.permission.GET_INSTALLED_BUNDLE_LIST`（受限权限，需在 AppGallery Connect
     申请；调试期可在自动签名生成的 debug profile 中添加 acl 字段）
3. 选择真机设备，Run ▶（或命令行：`hvigorw assembleHap --mode module -p product=default`）

安装后首次启动：
- 「订阅」页添加订阅或导入 YAML → 「启用」
- 「首页」点「连接」→ 系统弹出 VPN 授权 → 允许

## 4. 常见问题

**Q: `import hclashCore from 'libhclash_core.so'` 报找不到模块？**
A: 先完成第 2 步（生成 `libs/libhclash_core_rust.a`）；检查
`entry/src/main/cpp/types/libhclash_core/` 存在且 `entry/oh-package.json5`
包含该依赖，然后 `ohpm install` 重新同步。

**Q: CMake 报找不到 `libhclash_core_rust.a`？**
A: Rust 静态库未构建或路径不对。确认 `hclash/libs/libhclash_core_rust.a` 存在；
或在 CMake 参数中指定 `-DHCLASH_CORE_LIB_DIR=<dir>`。

**Q: 连接后没有网络？**
A: 依次排查：
1. 「设置 > 内核 > 日志级别」调到 debug，「日志」页查看内核是否启动成功
2. 「订阅」配置是否有效（代理页是否显示节点）
3. 手机 WLAN 代理设置是否被改为手动（系统 VPN 与 WLAN 代理互斥）
4. 部分运营商网络对 QUIC（Hysteria2/TUIC）有限制，可切换 TCP 类协议测试

**Q: 模拟器能用吗？**
A: UI 与本地代理（mixed 端口）可在模拟器验证，但 VPN 全局接管需要真机。

**Q: 如何调试 Rust 内核？**
A: `core/` 目录下 `cargo test`（配置注入与 SOCKS5 编解码有单元测试）；
本机调试可构建 host 目标并跑 `cargo run`，用 `curl -x` 验证代理链路。

## 5. 目录与产物

| 路径 | 说明 |
|------|------|
| `libs/libhclash_core_rust.a` | Rust 内核静态库（构建产物，不入库） |
| `entry/build/` | hvigor/DevEco 构建产物（不入库） |
| `core/target/` | cargo 构建产物（不入库） |
