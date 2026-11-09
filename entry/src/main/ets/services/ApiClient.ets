import http from '@ohos.net.http';
import webSocket from '@ohos.net.webSocket';
import { Log } from '../utils/Logger';
import {
  ConnectionsResp,
  DelayResp,
  GeneralConfig,
  ProxiesResp,
  ProxyInfo,
  RulesResp,
  TrafficFrame,
  LogEntry,
  VersionInfo
} from '../models/ClashTypes';

const TAG: string = 'ApiClient';
const DEFAULT_TIMEOUT: number = 8000;

/**
 * Clash External Controller 客户端。
 * 与 mihomo / clash-rs 内嵌的 RESTful API 通信（默认 127.0.0.1:9090）。
 * 参考：https://wiki.metacubex.one/api/
 */
export class ApiClient {
  private static _instance: ApiClient = new ApiClient();
  private host: string = '127.0.0.1';
  private port: number = 9090;
  private secret: string = '';

  private constructor() {
  }

  static get instance(): ApiClient {
    return ApiClient._instance;
  }

  /** 更新接入点（设置变更时调用） */
  configure(port: number, secret: string, host?: string): void {
    this.port = port;
    this.secret = secret;
    if (host !== undefined && host.length > 0) {
      this.host = host;
    }
  }

  private base(): string {
    return `http://${this.host}:${this.port}`;
  }

  private wsBase(): string {
    return `ws://${this.host}:${this.port}`;
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (this.secret.length > 0) {
      h['Authorization'] = `Bearer ${this.secret}`;
    }
    return h;
  }

  /**
   * 通用 JSON 请求。失败抛出 Error。
   */
  private async requestJson<T>(method: http.RequestMethod, path: string, body?: Object): Promise<T> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: this.headers(),
        connectTimeout: DEFAULT_TIMEOUT,
        readTimeout: DEFAULT_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      };
      if (body !== undefined) {
        options.extraData = JSON.stringify(body);
      }
      const resp: http.HttpResponse = await req.request(this.base() + path, options);
      if (resp.responseCode >= 400) {
        let msg: string = `HTTP ${resp.responseCode}`;
        if (typeof resp.result === 'string' && resp.result.length > 0) {
          try {
            const errObj: Record<string, string> = JSON.parse(resp.result) as Record<string, string>;
            if (errObj['message'] !== undefined) {
              msg = errObj['message'];
            }
          } catch (e) {
            msg = resp.result.substring(0, 120);
          }
        }
        throw new Error(msg);
      }
      if (resp.responseCode === 204 || resp.result === undefined || resp.result === '') {
        return {} as T;
      }
      return JSON.parse(resp.result as string) as T;
    } finally {
      req.destroy();
    }
  }

  /** 内核是否存活（GET /version） */
  async testAlive(): Promise<boolean> {
    try {
      const v: VersionInfo = await this.requestJson<VersionInfo>(http.RequestMethod.GET, '/version');
      return v.version !== undefined && v.version.length > 0;
    } catch (e) {
      return false;
    }
  }

  async getVersion(): Promise<VersionInfo> {
    return this.requestJson<VersionInfo>(http.RequestMethod.GET, '/version');
  }

  /** 全部代理与代理组（含内置 DIRECT/REJECT 等） */
  async getProxies(): Promise<Record<string, ProxyInfo>> {
    const resp: ProxiesResp = await this.requestJson<ProxiesResp>(http.RequestMethod.GET, '/proxies');
    return resp.proxies;
  }

  /** 测试节点延迟，返回毫秒；超时/失败返回 0 */
  async getProxyDelay(name: string, url: string, timeout: number): Promise<number> {
    try {
      const encName: string = encodeURIComponent(name);
      const encUrl: string = encodeURIComponent(url);
      const resp: DelayResp = await this.requestJson<DelayResp>(
        http.RequestMethod.GET, `/proxies/${encName}/delay?url=${encUrl}&timeout=${timeout}`);
      return resp.delay;
    } catch (e) {
      Log.d(TAG, `delay test failed for ${name}: ${Log.err(e)}`);
      return 0;
    }
  }

  /** 代理组选择节点 */
  async selectProxy(group: string, node: string): Promise<void> {
    const enc: string = encodeURIComponent(group);
    await this.requestJson<void>(http.RequestMethod.PUT, `/proxies/${enc}`, { name: node });
  }

  async getConfigs(): Promise<GeneralConfig> {
    return this.requestJson<GeneralConfig>(http.RequestMethod.GET, '/configs');
  }

  /** 增量修改运行时配置，如 { mode: 'global' } */
  async patchConfigs(patch: Object): Promise<void> {
    await this.requestJson<void>(http.RequestMethod.PATCH, '/configs', patch);
  }

  /** 重载配置文件（path 为内核进程侧路径；force 强制重载） */
  async reloadConfig(path: string, force: boolean): Promise<void> {
    const body: Record<string, Object> = {
      path: path,
      force: force
    };
    await this.requestJson<void>(http.RequestMethod.PUT, `/configs?force=${force}`, body);
  }

  async getRules(): Promise<RulesResp> {
    return this.requestJson<RulesResp>(http.RequestMethod.GET, '/rules');
  }

  async getConnections(): Promise<ConnectionsResp> {
    return this.requestJson<ConnectionsResp>(http.RequestMethod.GET, '/connections');
  }

  async closeConnection(id: string): Promise<void> {
    const enc: string = encodeURIComponent(id);
    await this.requestJson<void>(http.RequestMethod.DELETE, `/connections/${enc}`);
  }

  async closeAllConnections(): Promise<void> {
    await this.requestJson<void>(http.RequestMethod.DELETE, '/connections');
  }

  /** 实时流量 WebSocket（每秒一帧 {up, down}） */
  openTrafficWs(onFrame: (f: TrafficFrame) => void, onClose: () => void): ClashWs {
    return new ClashWs(`${this.wsBase()}/traffic`, (text: string) => {
      try {
        const f: TrafficFrame = JSON.parse(text) as TrafficFrame;
        onFrame(f);
      } catch (e) {
        // 忽略坏帧
      }
    }, onClose);
  }

  /** 实时日志 WebSocket（按级别过滤） */
  openLogsWs(level: string, onLog: (l: LogEntry) => void, onClose: () => void): ClashWs {
    return new ClashWs(`${this.wsBase()}/logs?level=${level}`, (text: string) => {
      try {
        const l: LogEntry = JSON.parse(text) as LogEntry;
        onLog(l);
      } catch (e) {
        // 忽略坏帧
      }
    }, onClose);
  }
}

/**
 * 轻量 WebSocket 封装，自动处理 open/error/close 与重连（最多 5 次，间隔 2s）。
 * 使用完毕必须 close()。
 */
export class ClashWs {
  private ws: webSocket.WebSocket = webSocket.createWebSocket();
  private url: string;
  private onText: (t: string) => void;
  private onClosed: () => void;
  private closedByUser: boolean = false;
  private retries: number = 0;
  private static MAX_RETRY: number = 5;

  constructor(url: string, onText: (t: string) => void, onClosed: () => void) {
    this.url = url;
    this.onText = onText;
    this.onClosed = onClosed;
    this.bind();
    this.connect();
  }

  private bind(): void {
    this.ws.on('stringMessage', (err: Object, value: string) => {
      if (err === undefined || err === null) {
        this.onText(value);
      }
    });
    this.ws.on('open', () => {
      this.retries = 0;
    });
    this.ws.on('close', () => {
      if (!this.closedByUser) {
        this.onClosed();
      }
    });
    this.ws.on('error', (err: Object) => {
      Log.w(TAG, `ws error: ${Log.err(err)}`);
    });
  }

  private connect(): void {
    this.ws.connect(this.url, (err: Object) => {
      if (err !== undefined && err !== null) {
        Log.w(TAG, `ws connect failed: ${Log.err(err)}`);
        this.retry();
      }
    });
  }

  private retry(): void {
    if (this.closedByUser) {
      return;
    }
    if (this.retries >= ClashWs.MAX_RETRY) {
      this.onClosed();
      return;
    }
    this.retries++;
    setTimeout(() => {
      this.connect();
    }, 2000);
  }

  close(): void {
    this.closedByUser = true;
    this.ws.close((err: Object) => {
      if (err !== undefined && err !== null) {
        Log.w(TAG, `ws close err: ${Log.err(err)}`);
      }
    });
  }
}
