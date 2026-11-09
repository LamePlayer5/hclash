import hclashCore from 'libhclash_core.so';
import { Log } from '../utils/Logger';

const TAG: string = 'CoreBridge';

/**
 * 原生内核的 NAPI 接口（对应 entry/src/main/cpp/napi_init.cpp，
 * 内嵌 clash-rs，见 core/ 目录）。
 */
export interface NativeCore {
  /**
   * 启动内核。
   * @param configPath Clash YAML 配置绝对路径
   * @param homeDir 内核工作目录（geoip/geosite/cache 存放处）
   * @param tunFd 系统 VPN 隧道 fd（-1 = 仅本地 mixed/http/socks 代理，不启用 TUN）
   * @param apiPort 外部控制器端口
   * @param logLevel 日志级别 silent/error/warning/info/debug
   * @returns 0 成功，非 0 失败
   */
  start(configPath: string, homeDir: string, tunFd: number, apiPort: number, logLevel: string): number;

  /** 停止内核并释放资源 */
  stop(): void;

  /** 内核版本字符串 */
  version(): string;
}

export interface CoreStartResult {
  ok: boolean;
  message: string;
  version: string;
}

/**
 * ArkTS 侧内核桥接封装。
 * 仅在 VpnExtAbility 进程中调用；UI 进程通过 RESTful API（ApiClient）与内核通信。
 */
export class CoreBridge {
  private static _instance: CoreBridge = new CoreBridge();
  private running: boolean = false;

  private constructor() {
  }

  static get instance(): CoreBridge {
    return CoreBridge._instance;
  }

  private core(): NativeCore {
    return hclashCore as NativeCore;
  }

  start(configPath: string, homeDir: string, tunFd: number, apiPort: number, logLevel: string): CoreStartResult {
    try {
      const rc: number = this.core().start(configPath, homeDir, tunFd, apiPort, logLevel);
      if (rc === 0) {
        this.running = true;
        return { ok: true, message: '', version: this.version() };
      }
      return { ok: false, message: `内核启动失败，错误码 ${rc}`, version: '' };
    } catch (e) {
      return { ok: false, message: Log.err(e), version: '' };
    }
  }

  stop(): void {
    try {
      this.core().stop();
    } catch (e) {
      Log.e(TAG, `stop failed: ${Log.err(e)}`);
    }
    this.running = false;
  }

  isRunning(): boolean {
    return this.running;
  }

  version(): string {
    try {
      return this.core().version();
    } catch (e) {
      return '';
    }
  }
}
