/**
 * libhclash_core.so 声明：
 * 启动/停止内嵌的 clash-rs 代理内核。
 */
export interface NativeCore {
  /**
   * 启动内核。
   * @param configPath Clash YAML 配置绝对路径
   * @param homeDir 内核工作目录（日志/geo 数据存放处）
   * @param tunFd 系统 VPN 隧道 fd（-1 = 仅本地 mixed 代理，不启用 TUN 中继）
   * @param apiPort 外部控制器端口（写入配置 external-controller: 127.0.0.1:apiPort）
   * @param logLevel 内核日志级别 silent/error/warning/info/debug
   * @returns 0 成功，1 参数错误，2 配置错误，3 启动失败，4 已在运行
   */
  start(configPath: string, homeDir: string, tunFd: number, apiPort: number, logLevel: string): number;

  /** 停止内核并释放资源（含 TUN 中继） */
  stop(): void;

  /** 内核版本字符串 */
  version(): string;
}

declare const core: NativeCore;
export default core;
