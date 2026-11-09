import { TrafficFrame } from '../models/ClashTypes';

/**
 * 全局应用状态（单例，@Observed）。
 * UI 通过 @State / @ObjectLink 绑定此对象的字段实现响应式刷新。
 */
@Observed
export class AppState {
  private static _instance: AppState = new AppState();

  /** 系统 VPN 是否已激活（尽力而为的状态推断） */
  vpnRunning: boolean = false;
  /** 内核 API 是否可连通 */
  coreRunning: boolean = false;
  /** 内核版本（clash-rs / mihomo） */
  coreVersion: string = '';
  /** 当前代理模式 */
  mode: string = 'rule';
  /** 当前选中的订阅名 */
  activeProfileName: string = '';
  /** 实时速率（字节/秒） */
  upSpeed: number = 0;
  downSpeed: number = 0;
  /** 累计流量（字节，来自 /connections 轮询累计） */
  upTotal: number = 0;
  downTotal: number = 0;
  /** 节点总数 */
  proxyCount: number = 0;
  /** 活动连接数 */
  connectionCount: number = 0;
  /** 本次启动时间（Unix 毫秒），0 表示未运行 */
  startedAt: number = 0;
  /** 最近一分钟流量采样（每秒一帧，用于仪表盘图表） */
  trafficHistory: TrafficFrame[] = [];

  private constructor() {
  }

  static get instance(): AppState {
    return AppState._instance;
  }

  pushTrafficFrame(f: TrafficFrame): void {
    this.upSpeed = f.up;
    this.downSpeed = f.down;
    this.upTotal += f.up;
    this.downTotal += f.down;
    this.trafficHistory.push(f);
    if (this.trafficHistory.length > 60) {
      this.trafficHistory.shift();
    }
  }

  resetRuntime(): void {
    this.vpnRunning = false;
    this.coreRunning = false;
    this.upSpeed = 0;
    this.downSpeed = 0;
    this.connectionCount = 0;
    this.startedAt = 0;
    this.trafficHistory = [];
  }
}
