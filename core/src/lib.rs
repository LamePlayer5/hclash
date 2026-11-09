//! HClash 内核桥接层（C ABI）。
//!
//! 该 crate 以 staticlib 形式构建为 `libhclash_core_rust.a`，
//! 由 `entry/src/main/cpp/napi_init.cpp`（NAPI shim）链接并封装为
//! `libhclash_core.so` 供 ArkTS 调用。
//!
//! 设计：
//! - `hclash_start`  加载 Clash YAML 配置（注入 external-controller 等运行参数），
//!   启动 clash-rs 内核（`clash_lib::start_scaffold`，与官方 clash-ffi 相同入口）；
//!   若 `tun_fd >= 0`，同时启动 TUN 中继（clash-netstack 用户态栈 + SOCKS5 出站），
//!   将系统 VPN 隧道流量经本地 mixed 端口送入内核策略引擎。
//! - `hclash_stop`   停止内核与 TUN 中继。
//! - `hclash_version` 返回内核版本字符串。

mod config;
mod engine;
mod socks5;
mod tun_relay;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

pub const VERSION: &str = "1.0.0 (clash-rs 0.10)";

/// 运行状态
struct Runtime {
    relay: Option<tun_relay::RelayHandle>,
}

static STARTED: AtomicBool = AtomicBool::new(false);
static RUNTIME: Mutex<Option<Runtime>> = Mutex::new(None);

fn err_code(e: &str) -> c_int {
    log::error!("[hclash-core] {e}");
    // 1 参数错误 / 2 配置错误 / 3 启动失败 / 4 已在运行
    if e.starts_with("param") {
        1
    } else if e.starts_with("config") {
        2
    } else if e.starts_with("running") {
        4
    } else {
        3
    }
}

/// 启动内核。
/// 返回 0 成功；非 0 见 `index.d.ts` 中的错误码说明。
#[no_mangle]
pub unsafe extern "C" fn hclash_start(
    config_path: *const c_char,
    home_dir: *const c_char,
    tun_fd: c_int,
    api_port: c_int,
    log_level: *const c_char,
) -> c_int {
    if config_path.is_null() || home_dir.is_null() {
        return err_code("param: null pointer");
    }
    let config_path = unsafe { CStr::from_ptr(config_path) }.to_string_lossy().to_string();
    let home_dir = unsafe { CStr::from_ptr(home_dir) }.to_string_lossy().to_string();
    let log_level = if log_level.is_null() {
        "info".to_string()
    } else {
        unsafe { CStr::from_ptr(log_level) }.to_string_lossy().to_string()
    };

    if STARTED.load(Ordering::SeqCst) {
        return err_code("running: core already started");
    }

    // 1. 读取并注入运行参数
    let raw = match std::fs::read_to_string(&config_path) {
        Ok(s) => s,
        Err(e) => return err_code(&format!("config: read failed: {e}")),
    };
    let patched = match config::patch(&raw, api_port, &log_level) {
        Ok(s) => s,
        Err(e) => return err_code(&format!("config: {e}")),
    };

    // 2. 启动 clash-rs 内核
    if let Err(e) = engine::start(&patched, &home_dir) {
        return err_code(&format!("start: {e}"));
    }

    // 3. 可选：启动 TUN 中继（VPN 全局接管模式）
    let relay = if tun_fd >= 0 {
        // 混合端口：优先取配置注入值；默认 7890
        let mixed_port = config::mixed_port(&raw).unwrap_or(7890);
        match tun_relay::RelayHandle::spawn(tun_fd as i32, mixed_port) {
            Ok(h) => {
                log::info!("[hclash-core] TUN relay started, fd={tun_fd}, mixed={mixed_port}");
                Some(h)
            }
            Err(e) => {
                log::error!("[hclash-core] TUN relay failed: {e}");
                None
            }
        }
    } else {
        None
    };

    if let Ok(mut rt) = RUNTIME.lock() {
        *rt = Some(Runtime { relay });
    }
    STARTED.store(true, Ordering::SeqCst);
    0
}

/// 停止内核并释放资源。
#[no_mangle]
pub extern "C" fn hclash_stop() {
    // 先停 TUN 中继，再停内核
    if let Ok(mut rt) = RUNTIME.lock() {
        if let Some(mut state) = rt.take() {
            if let Some(relay) = state.relay.take() {
                relay.stop();
            }
        }
    }
    engine::stop();
    STARTED.store(false, Ordering::SeqCst);
}

/// 内核版本（静态字符串，无需释放）。
#[no_mangle]
pub extern "C" fn hclash_version() -> *const c_char {
    static VER: Mutex<Option<CString>> = Mutex::new(None);
    if let Ok(mut v) = VER.lock() {
        if v.is_none() {
            *v = Some(CString::new(VERSION).unwrap());
        }
        return v.as_ref().unwrap().as_ptr();
    }
    std::ptr::null()
}

/// 释放 `hclash_version` 之外返回的动态字符串（预留）。
#[no_mangle]
pub unsafe extern "C" fn hclash_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    drop(unsafe { CString::from_raw(s) });
}
