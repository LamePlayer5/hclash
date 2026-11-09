//! Clash YAML 配置处理：
//! - `patch`：注入/覆盖 external-controller、log-level 等运行参数
//! - `mixed_port`：读取配置中的 mixed-port

use serde_yaml::{Mapping, Value};

/// 注入运行参数：external-controller（127.0.0.1:apiPort）与 log-level。
/// 其余配置原样保留。返回新的 YAML 文本。
pub fn patch(raw: &str, api_port: i32, log_level: &str) -> Result<String, String> {
    let root: Value = serde_yaml::from_str(raw).map_err(|e| format!("yaml parse: {e}"))?;
    let mut map = match root {
        Value::Mapping(m) => m,
        _ => return Err("yaml root is not a mapping".to_string()),
    };

    if api_port > 0 {
        map.insert(
            Value::String("external-controller".to_string()),
            Value::String(format!("127.0.0.1:{api_port}")),
        );
    }
    if !log_level.is_empty() {
        map.insert(
            Value::String("log-level".to_string()),
            Value::String(log_level.to_string()),
        );
    }

    serde_yaml::to_string(&Value::Mapping(map)).map_err(|e| format!("yaml dump: {e}"))
}

/// 提取配置中的 mixed-port；缺失或非法时返回 None。
pub fn mixed_port(raw: &str) -> Option<u16> {
    let root: Value = serde_yaml::from_str(raw).ok()?;
    let map = root.as_mapping()?;
    let v = map.get(Value::String("mixed-port".to_string()))?;
    v.as_u64().map(|n| n as u16)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_inserts_controller() {
        let out = patch("port: 7890\nmode: rule\n", 9090, "info").unwrap();
        assert!(out.contains("external-controller"));
        assert!(out.contains("127.0.0.1:9090"));
        assert!(out.contains("log-level"));
    }

    #[test]
    fn mixed_port_read() {
        assert_eq!(mixed_port("mixed-port: 7890\n"), Some(7890));
        assert_eq!(mixed_port("port: 1\n"), None);
    }
}
