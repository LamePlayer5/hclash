import { AbilityConstant, common, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { Log } from '../utils/Logger';
import { SettingsStore } from '../services/SettingsStore';
import { ProfileManager } from '../services/ProfileManager';
import { VpnService } from '../services/VpnService';
import { ApiClient } from '../services/ApiClient';
import { AppState } from '../services/AppState';
import { Profile } from '../models/Profile';

const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Log.i(TAG, 'onCreate');
    // 初始化基础设施（顺序敏感：设置 → 档案 → VPN 服务）
    SettingsStore.instance.init(this.context);
    ProfileManager.instance.init(this.context);
    VpnService.instance.init(this.context);
    const s = SettingsStore.instance.settings;
    ApiClient.instance.configure(s.apiPort, s.apiSecret);
    const cur: Profile | undefined = ProfileManager.instance.current();
    if (cur !== undefined) {
      AppState.instance.activeProfileName = cur.name;
      AppState.instance.mode = s.mode;
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Log.i(TAG, 'onNewWant');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Log.i(TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err: BusinessError<void>) => {
      if (err.code) {
        Log.e(TAG, `loadContent failed: ${JSON.stringify(err)}`);
        return;
      }
      Log.i(TAG, 'loadContent succeeded');
    });
    // 启动状态轮询（用于检测内核/VPN 运行状态）
    VpnService.instance.startStateLoop();
    // 可选：启动时自动连接
    const s = SettingsStore.instance.settings;
    if (s.connectOnLaunch && ProfileManager.instance.current() !== undefined) {
      setTimeout(() => {
        VpnService.instance.startVpn().catch((e: Object) => {
          Log.w(TAG, `auto connect failed: ${Log.err(e)}`);
        });
      }, 800);
    }
  }

  onForeground(): void {
    VpnService.instance.startStateLoop();
  }

  onBackground(): void {
    VpnService.instance.stopStateLoop();
  }

  onWindowStageDestroy(): void {
    Log.i(TAG, 'onWindowStageDestroy');
  }

  onDestroy(): void {
    Log.i(TAG, 'onDestroy');
    VpnService.instance.stopStateLoop();
  }
}
