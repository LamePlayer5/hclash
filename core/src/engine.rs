//! clash-rs 引擎封装。
//! 与官方 clash-ffi 相同的启动入口：`clash_lib::{Config, Options, TokioRuntime, start_scaffold, shutdown}`。

use clash_lib::{shutdown, start_scaffold, Config, Options, TokioRuntime};

/// 启动 clash-rs 引擎（配置内容以字符串传入，工作目录为 home_dir）。
pub fn start(config_str: &str, home_dir: &str) -> Result<(), String> {
    let log_file = format!("{home_dir}/hclash-core.log");
    let options = Options {
        config: Config::Str(config_str.to_string()),
        cwd: Some(home_dir.to_string()),
        rt: Some(TokioRuntime::MultiThread),
        log_file: Some(log_file),
        config_path: None,
    };
    start_scaffold(options).map_err(|e| format!("{e}"))?;
    Ok(())
}

/// 停止引擎。返回是否成功。
pub fn stop() -> bool {
    shutdown()
}
