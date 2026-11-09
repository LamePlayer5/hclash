# HClash 内核交叉编译脚本（Windows）
# 产出：libs/libhclash_core_rust.a（arm64-v8a / aarch64-unknown-linux-ohos）
#
# 前置条件：
#   1. Rust 工具链（https://rustup.rs）
#   2. OpenHarmony SDK 的 native 工具链（DevEco Studio 自带，或从
#      https://developer.huawei.com/consumer/cn/download/ 下载 Command Line Tools）
#   3. 可选：设置环境变量 OHOS_SDK_NATIVE 指向 SDK native 目录，
#      否则脚本会尝试常见安装路径
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1
#   powershell -ExecutionPolicy Bypass -File core\build-ohos.ps1 -SdkPath "C:\OpenHarmony\Sdk\12\native"

param(
    [string]$SdkPath = $env:OHOS_SDK_NATIVE
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# 1. 定位 OHOS native 工具链
if (-not $SdkPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\OpenHarmony\Sdk\*\native",
        "C:\OpenHarmony\Sdk\*\native",
        "C:\Program Files\Huawei\DevEco Studio\sdk\*\native",
        "$env:USERPROFILE\OpenHarmony\Sdk\*\native"
    )
    foreach ($c in $candidates) {
        $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $SdkPath = $found.FullName; break }
    }
}
if (-not $SdkPath -or -not (Test-Path $SdkPath)) {
    Write-Error "未找到 OHOS SDK native 工具链。请安装 DevEco Studio SDK 或指定 -SdkPath"
}
$clang = Join-Path $SdkPath "llvm\bin\clang.exe"
if (-not (Test-Path $clang)) {
    Write-Error "未找到 clang：$clang"
}
Write-Host "[1/4] OHOS native 工具链：$SdkPath"

# 2. 安装目标（nightly 工具链，见 rust-toolchain.toml）
rustup toolchain install nightly --profile minimal
rustup target add --toolchain nightly aarch64-unknown-linux-ohos

# 3. 配置链接器（写入环境变量供 cargo 使用）
$env:CC_aarch64_unknown_linux_ohos = $clang
$env:CXX_aarch64_unknown_linux_ohos = (Join-Path $SdkPath "llvm\bin\clang++.exe")
$env:AR_aarch64_unknown_linux_ohos = (Join-Path $SdkPath "llvm\bin\llvm-ar.exe")
$env:CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER = $clang
$env:CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_RUSTFLAGS = "-C link-arg=-fuse-ld=lld"

Write-Host "[2/4] 开始编译 hclash-core (release, aarch64-unknown-linux-ohos)"
Push-Location $PSScriptRoot
try {
    cargo build --release --target aarch64-unknown-linux-ohos
    if ($LASTEXITCODE -ne 0) { Write-Error "cargo build 失败" }
}
finally {
    Pop-Location
}

# 4. 拷贝产物
$outDir = Join-Path $root "libs"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$src = Join-Path $PSScriptRoot "target\aarch64-unknown-linux-ohos\release\libhclash_core_rust.a"
Copy-Item $src (Join-Path $outDir "libhclash_core_rust.a") -Force
Write-Host "[3/4] 产物已拷贝：libs\libhclash_core_rust.a"
Write-Host "[4/4] 完成。现在可用 DevEco Studio / hvigor 构建 HAP。"
