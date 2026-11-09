import { bundleManager } from '@kit.AbilityKit';
import { Log } from '../utils/Logger';

const TAG: string = 'AppListService';

export interface InstalledApp {
  bundleName: string;
  label: string;
}

/**
 * 已安装应用列表（分应用代理用）。
 * 需要 ohos.permission.GET_INSTALLED_BUNDLE_LIST（受限权限，需在 DevEco 签名时申请 ACL）。
 * 未授权时返回空列表，UI 应提示用户。
 *
 * 说明：其他应用的 label 为 Resource 引用，无法跨应用解析，
 * 这里用包名末段作为展示名（如 com.tencent.mm → mm），与多数分应用代理实现一致。
 */
export class AppListService {
  private static _instance: AppListService = new AppListService();
  private cached: InstalledApp[] = [];
  private loaded: boolean = false;

  private constructor() {
  }

  static get instance(): AppListService {
    return AppListService._instance;
  }

  async listInstalled(force: boolean): Promise<InstalledApp[]> {
    if (this.loaded && !force) {
      return this.cached;
    }
    try {
      const flags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      // getBundleInfoList(flags, startIndex, length)
      const list = await bundleManager.getBundleInfoList(flags, 0, 100);
      const apps: InstalledApp[] = [];
      for (const info of list) {
        const bundleName: string = info.name;
        // 过滤自身
        if (bundleName === 'com.hclash.app') {
          continue;
        }
        apps.push({ bundleName: bundleName, label: AppListService.displayName(bundleName) });
      }
      apps.sort((a: InstalledApp, b: InstalledApp) => a.label.localeCompare(b.label));
      this.cached = apps;
      this.loaded = true;
    } catch (e) {
      Log.e(TAG, `listInstalled failed: ${Log.err(e)}`);
      this.cached = [];
      this.loaded = false;
    }
    return this.cached;
  }

  /** 包名末段作为展示名 */
  private static displayName(bundleName: string): string {
    const idx: number = bundleName.lastIndexOf('.');
    if (idx >= 0 && idx + 1 < bundleName.length) {
      return bundleName.substring(idx + 1);
    }
    return bundleName;
  }
}
