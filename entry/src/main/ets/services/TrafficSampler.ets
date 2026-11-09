import { ApiClient, ClashWs } from './ApiClient';
import { AppState } from './AppState';
import { Log } from '../utils/Logger';

const TAG: string = 'TrafficSampler';

/**
 * 实时流量采样：通过 /traffic WebSocket 每秒更新 AppState。
 * VPN 运行时启动，停止时关闭。
 */
export class TrafficSampler {
  private static _instance: TrafficSampler = new TrafficSampler();
  private ws: ClashWs | undefined = undefined;
  private active: boolean = false;

  private constructor() {
  }

  static get instance(): TrafficSampler {
    return TrafficSampler._instance;
  }

  start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.connect();
  }

  private connect(): void {
    if (!this.active) {
      return;
    }
    try {
      this.ws = ApiClient.instance.openTrafficWs((f) => {
        AppState.instance.pushTrafficFrame(f);
      }, () => {
        // 连接断开：3 秒后重试（内核可能重启中）
        this.ws = undefined;
        if (this.active) {
          setTimeout(() => {
            this.connect();
          }, 3000);
        }
      });
    } catch (e) {
      Log.e(TAG, `connect failed: ${Log.err(e)}`);
    }
  }

  stop(): void {
    this.active = false;
    if (this.ws !== undefined) {
      this.ws.close();
      this.ws = undefined;
    }
  }
}
