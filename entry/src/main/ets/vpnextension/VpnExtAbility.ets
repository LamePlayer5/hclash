import { VpnExtensionAbility, vpnExtension, VpnExtensionContext } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Log } from '../utils/Logger';
import { CoreBridge } from '../services/CoreBridge';
import { RuntimeConfig } from '../services/VpnService';
import { buildVpnConfig } from './VpnConfigBuilder';

const TAG: string = 'VpnExtAbility';

/**
 * VPN 隧道扩展（独立进程，:vpn）。
 * 生命周期由系统管理：
 *   startVpnExtensionAbility → onCreate → （建立隧道 + 启动内核）
 *   stopVpnExtensionAbility  → onDisconnect/onDestroy → （停止内核 + 销毁隧道）
 *
 * 说明：权限与能力声明见 module.json5（type: "vpn"）。
 */
export default class VpnExtAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | undefined = undefined;
  private runtime: RuntimeConfig | undefined = undefined;
  private tunFd: number = -1;
  private started: boolean = false;

  onCreate(want: Want): void {
    Log.i(TAG, 'onCreate');
    const ctx: VpnExtensionContext = this.context as VpnExtensionContext;
    try {
      this.runtime = this.readRuntime(ctx);
      this.vpnConnection = vpnExtension.createVpnConnection(ctx);
      this.establish();
    } catch (e) {
      Log.e(TAG, `onCreate failed: ${Log.err(e)}`);
    }
  }

  onConnect(want: Want): void {
    Log.i(TAG, 'onConnect');
  }

  onDisconnect(): void {
    Log.i(TAG, 'onDisconnect');
    this.teardown();
  }

  onDestroy(): void {
    Log.i(TAG, 'onDestroy');
    this.teardown();
  }

  /** 建立隧道并启动内核 */
  private establish(): void {
    const ctx: VpnExtensionContext = this.context as VpnExtensionContext;
    if (this.runtime === undefined || this.vpnConnection === undefined) {
      Log.e(TAG, 'establish: runtime/vpnConnection missing');
      return;
    }
    const runtime: RuntimeConfig = this.runtime;
    const config: vpnExtension.VpnConfig = buildVpnConfig(runtime);
    Log.i(TAG, `create tunnel, mtu=${config.mtu}, dns=${JSON.stringify(config.dnsAddresses)}`);
    this.vpnConnection.create(config).then((fd: number) => {
      this.tunFd = fd;
      Log.i(TAG, `tunnel created, fd=${fd}`);
      // 启动内核（clash-rs），将 TUN fd 交给内核读写
      const result = CoreBridge.instance.start(
        runtime.configPath,
        runtime.homeDir,
        fd,
        runtime.apiPort,
        runtime.logLevel
      );
      if (result.ok) {
        this.started = true;
        Log.i(TAG, `core started: ${result.version}`);
      } else {
        Log.e(TAG, `core start failed: ${result.message}`);
        this.teardown();
      }
    }).catch((e: Object) => {
      Log.e(TAG, `tunnel create failed: ${Log.err(e)}`);
    });
  }

  /** 停止内核并销毁隧道 */
  private teardown(): void {
    if (this.started) {
      CoreBridge.instance.stop();
      this.started = false;
    }
    if (this.vpnConnection !== undefined) {
      try {
        this.vpnConnection.destroy();
      } catch (e) {
        Log.w(TAG, `vpnConnection.destroy: ${Log.err(e)}`);
      }
      this.vpnConnection = undefined;
    }
    this.tunFd = -1;
  }

  /** 读取 UI 进程写入的 runtime.json */
  private readRuntime(ctx: VpnExtensionContext): RuntimeConfig {
    const path: string = `${ctx.filesDir}/runtime.json`;
    if (!fs.accessSync(path)) {
      throw new Error('runtime.json 不存在，请从 App 内启动 VPN');
    }
    const text: string = fs.readTextSync(path);
    return JSON.parse(text) as RuntimeConfig;
  }
}
