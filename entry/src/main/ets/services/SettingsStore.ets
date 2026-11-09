import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppSettings, defaultSettings, PerAppMode, PerAppProxy } from '../models/Settings';
import { Log } from '../utils/Logger';

const TAG: string = 'SettingsStore';
const STORE_NAME: string = 'hclash_settings';
const KEY_SETTINGS: string = 'app_settings';

/**
 * 应用设置持久化（preferences）。
 * 使用前必须 init(context)。
 */
export class SettingsStore {
  private static _instance: SettingsStore = new SettingsStore();
  private prefs: preferences.Preferences | undefined = undefined;
  private cached: AppSettings = defaultSettings();

  private constructor() {
  }

  static get instance(): SettingsStore {
    return SettingsStore._instance;
  }

  init(context: common.Context): void {
    if (this.prefs !== undefined) {
      return;
    }
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw: string = this.prefs.getSync(KEY_SETTINGS, '') as string;
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed: AppSettings = JSON.parse(raw) as AppSettings;
        // 与默认值合并，保证新增字段有兜底
        this.cached = this.mergeWithDefault(parsed);
      }
    } catch (e) {
      Log.e(TAG, `init failed: ${Log.err(e)}`);
      this.cached = defaultSettings();
    }
  }

  private mergeWithDefault(parsed: AppSettings): AppSettings {
    const def: AppSettings = defaultSettings();
    const merged: AppSettings = Object.assign({}, def, parsed) as AppSettings;
    if (parsed.perApp === undefined || parsed.perApp === null) {
      merged.perApp = def.perApp;
    }
    if (merged.dnsServers === undefined || merged.dnsServers === null || merged.dnsServers.length === 0) {
      merged.dnsServers = def.dnsServers;
    }
    return merged;
  }

  get settings(): AppSettings {
    return this.cached;
  }

  /** 更新并持久化整个设置对象 */
  update(patch: Partial<AppSettings>): void {
    this.cached = Object.assign({}, this.cached, patch) as AppSettings;
    this.save();
  }

  updatePerApp(perApp: PerAppProxy): void {
    this.cached.perApp = perApp;
    this.save();
  }

  private save(): void {
    if (this.prefs === undefined) {
      return;
    }
    try {
      this.prefs.putSync(KEY_SETTINGS, JSON.stringify(this.cached));
      this.prefs.flush();
    } catch (e) {
      Log.e(TAG, `save failed: ${Log.err(e)}`);
    }
  }

  /** 是否为深色主题（当前版本默认深色） */
  isDark(): boolean {
    return this.cached.themeMode !== 'light';
  }

  getPerAppMode(): PerAppMode {
    return this.cached.perApp.mode;
  }
}
