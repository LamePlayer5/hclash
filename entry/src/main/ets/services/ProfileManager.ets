import { fileIo as fs } from '@kit.CoreFileKit';
import http from '@ohos.net.http';
import { common } from '@kit.AbilityKit';
import { Log } from '../utils/Logger';
import {
  newProfileId,
  Profile,
  ProfileStore,
  SubscriptionInfo,
  SUBSCRIPTION_UA
} from '../models/Profile';

const TAG: string = 'ProfileManager';
const META_FILE: string = 'meta.json';
const PROFILES_DIR: string = 'profiles';
const ACTIVE_FILE: string = 'active.yaml';
const RUNTIME_FILE: string = 'runtime.json';
const DEFAULT_TIMEOUT: number = 30000;

/**
 * 订阅档案管理：
 * - profiles 元数据持久化在 filesDir/profiles/meta.json
 * - 每个订阅的 YAML 存于 filesDir/profiles/<id>.yaml
 * - 选中的订阅被复制为 filesDir/active.yaml，供内核加载
 */
export class ProfileManager {
  private static _instance: ProfileManager = new ProfileManager();
  private context: common.Context | undefined = undefined;
  private store: ProfileStore = { current: '', profiles: [] };

  private constructor() {
  }

  static get instance(): ProfileManager {
    return ProfileManager._instance;
  }

  /** 初始化（EntryAbility 启动时调用一次） */
  init(context: common.Context): void {
    this.context = context;
    try {
      const dir: string = this.profilesDir();
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      this.load();
    } catch (e) {
      Log.e(TAG, `init failed: ${Log.err(e)}`);
    }
  }

  private requireContext(): common.Context {
    if (this.context === undefined) {
      throw new Error('ProfileManager not initialized');
    }
    return this.context;
  }

  private filesDir(): string {
    return this.requireContext().filesDir;
  }

  profilesDir(): string {
    return `${this.filesDir()}/${PROFILES_DIR}`;
  }

  /** 内核最终加载的配置文件路径 */
  activeConfigPath(): string {
    return `${this.filesDir()}/${ACTIVE_FILE}`;
  }

  runtimeConfigPath(): string {
    return `${this.filesDir()}/${RUNTIME_FILE}`;
  }

  private metaPath(): string {
    return `${this.profilesDir()}/${META_FILE}`;
  }

  private load(): void {
    try {
      if (fs.accessSync(this.metaPath())) {
        const text: string = fs.readTextSync(this.metaPath());
        this.store = JSON.parse(text) as ProfileStore;
      }
    } catch (e) {
      Log.e(TAG, `load meta failed: ${Log.err(e)}`);
      this.store = { current: '', profiles: [] };
    }
  }

  private save(): void {
    try {
      const fd: fs.File = fs.openSync(this.metaPath(), fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(fd.fd, JSON.stringify(this.store));
      } finally {
        fs.closeSync(fd);
      }
    } catch (e) {
      Log.e(TAG, `save meta failed: ${Log.err(e)}`);
    }
  }

  list(): Profile[] {
    return this.store.profiles;
  }

  currentId(): string {
    return this.store.current;
  }

  current(): Profile | undefined {
    for (const p of this.store.profiles) {
      if (p.id === this.store.current) {
        return p;
      }
    }
    return undefined;
  }

  hasProfiles(): boolean {
    return this.store.profiles.length > 0;
  }

  /**
   * 从订阅 URL 添加新档案。
   * 解析响应头 subscription-userinfo 提取流量信息（与 Clash Verge 行为一致）。
   */
  async addFromUrl(name: string, url: string, interval: number): Promise<Profile> {
    const content: string = await this.download(url);
    if (!this.looksLikeClashConfig(content)) {
      throw new Error('订阅内容不是有效的 Clash 配置（缺少 proxies 字段）');
    }
    const id: string = newProfileId();
    const fileName: string = `${id}.yaml`;
    this.writeFile(`${this.profilesDir()}/${fileName}`, content);
    const profile: Profile = {
      id: id,
      name: name.length > 0 ? name : this.inferName(url),
      url: url,
      file: fileName,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      interval: interval,
      subInfo: this.lastSubInfo
    };
    this.store.profiles.push(profile);
    this.save();
    return profile;
  }

  /** 从本地 YAML 文本导入 */
  addLocal(name: string, content: string): Profile {
    if (!this.looksLikeClashConfig(content)) {
      throw new Error('内容不是有效的 Clash 配置（缺少 proxies 字段）');
    }
    const id: string = newProfileId();
    const fileName: string = `${id}.yaml`;
    this.writeFile(`${this.profilesDir()}/${fileName}`, content);
    const profile: Profile = {
      id: id,
      name: name.length > 0 ? name : '本地配置',
      url: '',
      file: fileName,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      interval: 0
    };
    this.store.profiles.push(profile);
    this.save();
    return profile;
  }

  /** 更新订阅（重新下载）。本地档案返回 false。 */
  async update(id: string): Promise<boolean> {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined || p.url.length === 0) {
      return false;
    }
    const content: string = await this.download(p.url);
    if (!this.looksLikeClashConfig(content)) {
      throw new Error('订阅内容不是有效的 Clash 配置');
    }
    this.writeFile(`${this.profilesDir()}/${p.file}`, content);
    p.updatedAt = Date.now();
    p.subInfo = this.lastSubInfo;
    this.save();
    // 若更新的是当前激活档案，同步刷新 active.yaml
    if (this.store.current === id) {
      this.copyToActive(p);
    }
    return true;
  }

  /** 删除档案；若删除当前档案则清空激活状态 */
  remove(id: string): void {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined) {
      return;
    }
    try {
      fs.unlink(`${this.profilesDir()}/${p.file}`);
    } catch (e) {
      Log.w(TAG, `remove file failed: ${Log.err(e)}`);
    }
    this.store.profiles = this.store.profiles.filter((it: Profile) => it.id !== id);
    if (this.store.current === id) {
      this.store.current = '';
      try {
        fs.unlink(this.activeConfigPath());
      } catch (e) {
        // 忽略
      }
    }
    this.save();
  }

  rename(id: string, name: string): void {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined) {
      return;
    }
    p.name = name;
    this.save();
  }

  setInterval(id: string, interval: number): void {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined) {
      return;
    }
    p.interval = interval;
    this.save();
  }

  /** 选中档案：复制其 YAML 为 active.yaml */
  select(id: string): void {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined) {
      throw new Error('配置不存在');
    }
    this.copyToActive(p);
    this.store.current = id;
    this.save();
  }

  /** 读取当前激活配置的 YAML 文本（用于预览/编辑） */
  readActiveYaml(): string {
    if (!fs.accessSync(this.activeConfigPath())) {
      return '';
    }
    try {
      return fs.readTextSync(this.activeConfigPath());
    } catch (e) {
      return '';
    }
  }

  readProfileYaml(id: string): string {
    const p: Profile | undefined = this.findById(id);
    if (p === undefined) {
      return '';
    }
    try {
      return fs.readTextSync(`${this.profilesDir()}/${p.file}`);
    } catch (e) {
      return '';
    }
  }

  private findById(id: string): Profile | undefined {
    for (const p of this.store.profiles) {
      if (p.id === id) {
        return p;
      }
    }
    return undefined;
  }

  private copyToActive(p: Profile): void {
    const src: string = `${this.profilesDir()}/${p.file}`;
    const dst: string = this.activeConfigPath();
    const content: string = fs.readTextSync(src);
    this.writeFile(dst, content);
  }

  private writeFile(path: string, content: string): void {
    const fd: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(fd.fd, content);
    } finally {
      fs.closeSync(fd);
    }
  }

  /** 简单判断 YAML 是否为 Clash 配置（含 proxies: 或 proxy-providers:） */
  private looksLikeClashConfig(content: string): boolean {
    return content.includes('proxies:') || content.includes('proxy-providers:') || content.includes('Proxy:');
  }

  private inferName(url: string): string {
    try {
      const u: string = url.replace(/^https?:\/\//, '');
      const host: string = u.split('/')[0];
      return host.length > 0 ? host : '订阅配置';
    } catch (e) {
      return '订阅配置';
    }
  }

  // ---- 订阅下载 ----

  private lastSubInfo: SubscriptionInfo | undefined = undefined;

  private async download(url: string): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': SUBSCRIPTION_UA,
          'Accept': '*/*'
        },
        connectTimeout: DEFAULT_TIMEOUT,
        readTimeout: DEFAULT_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode >= 400) {
        throw new Error(`订阅下载失败：HTTP ${resp.responseCode}`);
      }
      this.lastSubInfo = this.parseSubInfo(resp.header);
      const text: string = resp.result as string;
      if (text === undefined || text.length === 0) {
        throw new Error('订阅内容为空');
      }
      return text;
    } finally {
      req.destroy();
    }
  }

  private parseSubInfo(header: Object): SubscriptionInfo | undefined {
    try {
      const h: Record<string, Object> = header as Record<string, Object>;
      let raw: string = '';
      const keys: string[] = Object.keys(h);
      for (const k of keys) {
        if (k.toLowerCase() === 'subscription-userinfo') {
          raw = h[k] as string;
          break;
        }
      }
      if (raw.length === 0) {
        return undefined;
      }
      const info: SubscriptionInfo = { upload: 0, download: 0, total: 0, expire: 0 };
      const parts: string[] = raw.split(';');
      for (const part of parts) {
        const kv: string[] = part.trim().split('=');
        if (kv.length !== 2) {
          continue;
        }
        const key: string = kv[0].trim();
        const val: number = Number(kv[1].trim());
        if (key === 'upload') {
          info.upload = val;
        } else if (key === 'download') {
          info.download = val;
        } else if (key === 'total') {
          info.total = val;
        } else if (key === 'expire') {
          info.expire = val;
        }
      }
      return info;
    } catch (e) {
      return undefined;
    }
  }
}
