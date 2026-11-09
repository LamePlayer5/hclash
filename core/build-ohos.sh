#!/usr/bin/env bash
# HClash 内核交叉编译脚本（macOS / Linux）
# 产出：libs/libhclash_core_rust.a（arm64-v8a / aarch64-unknown-linux-ohos）
#
# 用法：
#   ./core/build-ohos.sh
#   OHOS_SDK_NATIVE=~/OpenHarmony/Sdk/12/native ./core/build-ohos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 定位 OHOS native 工具链
SDK_PATH="${OHOS_SDK_NATIVE:-}"
if [ -z "$SDK_PATH" ]; then
  for c in "$HOME/OpenHarmony/Sdk"/*/native "$HOME/Library/OpenHarmony/Sdk"/*/native "/usr/local/OpenHarmony/Sdk"/*/native; do
    if [ -d "$c" ]; then SDK_PATH="$c"; break; fi
  done
fi
if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
  echo "未找到 OHOS SDK native 工具链。请设置 OHOS_SDK_NATIVE 环境变量。" >&2
  exit 1
fi
CLANG="$SDK_PATH/llvm/bin/clang"
if [ ! -x "$CLANG" ]; then
  echo "未找到 clang：$CLANG" >&2
  exit 1
fi
echo "[1/4] OHOS native 工具链：$SDK_PATH"

# 2. 安装目标（nightly 工具链，见 rust-toolchain.toml）
rustup toolchain install nightly --profile minimal
rustup target add --toolchain nightly aarch64-unknown-linux-ohos

# 3. 编译
export CC_aarch64_unknown_linux_ohos="$CLANG"
export CXX_aarch64_unknown_linux_ohos="$SDK_PATH/llvm/bin/clang++"
export AR_aarch64_unknown_linux_ohos="$SDK_PATH/llvm/bin/llvm-ar"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$CLANG"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_RUSTFLAGS="-C link-arg=-fuse-ld=lld"

echo "[2/4] 开始编译 hclash-core (release, aarch64-unknown-linux-ohos)"
(cd "$SCRIPT_DIR" && cargo build --release --target aarch64-unknown-linux-ohos)

# 4. 拷贝产物
mkdir -p "$ROOT/libs"
cp "$SCRIPT_DIR/target/aarch64-unknown-linux-ohos/release/libhclash_core_rust.a" "$ROOT/libs/libhclash_core_rust.a"
echo "[3/4] 产物已拷贝：libs/libhclash_core_rust.a"
echo "[4/4] 完成。现在可用 DevEco Studio / hvigor 构建 HAP。"
