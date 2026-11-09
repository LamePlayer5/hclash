import { common, Want } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Log } from '../utils/Logger';
import { AppState } from './AppState';
import { ApiClient } from './ApiClient';
import { ProfileManager } from './ProfileManager';
import { SettingsStore } from './SettingsStore';
import { AppSettings, PerAppMode } from '../models/Settings';

const TAG: string = 'VpnService';
const VPN_ABILITY_NAME: string = 'VpnExtAbility';

/**
 * VPN 控制服务（运行在 UI 进程）：
 * - 负责准备内核运行时配置（runtime.json）
 * - 通过 vpnExtension 启动/停止 VpnExtAbility（内核在扩展进程中运行）
 * - 轮询内核 API 刷新全局状态
 */
export class VpnService {
  private static _instance: VpnService = new VpnService();
  private context: common.UIAbilityContext | undefined = undefined;
  private stateTimer: number = -1;

  private constructor() {
  }

  static get instance(): VpnService {
    return VpnService._instance;
  }

  init(context: common.UIAbilityContext): void {
    this.context = context;
  }

  private requireContext(): common.UIAbilityContext {
    if (this.context === undefined) {
      throw new Error('VpnService not initialized');
    }
    return this.context;
  }

  /** 启动 VPN（会弹出系统 VPN 授权框，首次需要用户确认） */
  async startVpn(): Promise<void> {
    const pm: ProfileManager = ProfileManager.instance;
    if (pm.current() === undefined) {
      throw new Error('请先在「订阅」页选择或添加一个配置');
    }
    if (!fs.accessSync(pm.activeConfigPath())) {
      throw new Error('激活配置不存在，请重新选择配置');
    }
    this.writeRuntimeConfig();
    const ctx: common.UIAbilityContext = this.requireContext();
    const want: Want = {
      bundleName: ctx.applicationInfo.name,
      abilityName: VPN_ABILITY_NAME
    };
    Log.i(TAG, `startVpnExtensionAbility: ${want.bundleName}/${want.abilityName}`);
    await vpnExtension.startVpnExtensionAbility(want);
    AppState.instance.vpnRunning = true;
    AppState.instance.startedAt = Date.now();
    this.startStateLoop();
  }

  /** 停止 VPN */
  async stopVpn(): Promise<void> {
    const ctx: common.UIAbilityContext = this.requireContext();
    const want: Want = {
      bundleName: ctx.applicationInfo.name,
      abilityName: VPN_ABILITY_NAME
    };
    try {
      await vpnExtension.stopVpnExtensionAbility(want);
    } catch (e) {
      Log.w(TAG, `stopVpnExtensionAbility: ${Log.err(e)}`);
    }
    AppState.instance.resetRuntime();
    this.stopStateLoop();
  }

  /**
   * 生成 runtime.json —— VpnExtAbility 启动时读取。
   * 包含隧道参数、DNS、分应用代理与内核参数。
   */
  private writeRuntimeConfig(): void {
    const s: AppSettings = SettingsStore.instance.settings;
    const pm: ProfileManager = ProfileManager.instance;
    const runtime: RuntimeConfig = {
      configPath: pm.activeConfigPath(),
      homeDir: pm.profilesDir(),
      apiPort: s.apiPort,
      apiSecret: s.apiSecret,
      logLevel: s.logLevel,
      mtu: s.tunMtu,
      dnsServers: s.dnsServers,
      ipv6: s.ipv6,
      bypassPrivate: s.bypassPrivateNetworks,
      perAppMode: s.perApp.mode,
      perAppPackages: s.perApp.packages,
      mode: s.mode
    };
    const path: string = pm.runtimeConfigPath();
    const fd: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(fd.fd, JSON.stringify(runtime));
    } finally {
      fs.closeSync(fd);
    }
    Log.i(TAG, `runtime config written: ${path}`);
  }

  /** 周期刷新状态：内核存活 + 版本 + 连接数 */
  startStateLoop(): void {
    if (this.stateTimer >= 0) {
      return;
    }
    this.stateTimer = setInterval(() => {
      this.refreshState();
    }, 3000);
    this.refreshState();
  }

  stopStateLoop(): void {
    if (this.stateTimer >= 0) {
      clearInterval(this.stateTimer);
      this.stateTimer = -1;
    }
  }

  async refreshState(): Promise<void> {
    const s: AppSettings = SettingsStore.instance.settings;
    ApiClient.instance.configure(s.apiPort, s.apiSecret);
    const alive: boolean = await ApiClient.instance.testAlive();
    const state: AppState = AppState.instance;
    state.coreRunning = alive;
    if (alive) {
      state.vpnRunning = true;
      if (state.startedAt === 0) {
        state.startedAt = Date.now();
      }
      try {
        const v = await ApiClient.instance.getVersion();
        state.coreVersion = v.version;
      } catch (e) {
        // 忽略
      }
      try {
        const cfg = await ApiClient.instance.getConfigs();
        if (cfg.mode !== undefined) {
          state.mode = cfg.mode;
        }
      } catch (e) {
        // 忽略
      }
      try {
        const conns = await ApiClient.instance.getConnections();
        state.connectionCount = conns.connections.length;
      } catch (e) {
        // 忽略
      }
    } else if (state.vpnRunning) {
      // VPN 显示运行但内核不可达：可能内核正在启动，保守处理
      Log.d(TAG, 'core not reachable yet');
    }
  }
}

/** runtime.json 的序列化结构（UI 写，VPN 扩展读） */
export interface RuntimeConfig {
  configPath: string;
  homeDir: string;
  apiPort: number;
  apiSecret: string;
  logLevel: string;
  mtu: number;
  dnsServers: string[];
  ipv6: boolean;
  bypassPrivate: boolean;
  perAppMode: PerAppMode;
  perAppPackages: string[];
  mode: string;
}
