import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import http from '@ohos.net.http';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient } from '../services/ApiClient';
import { SettingsStore } from '../services/SettingsStore';
import { AppSettings, PerAppMode } from '../models/Settings';
import { SectionHeader } from '../components/SectionHeader';
import { formatBytes } from '../utils/Format';

const GEOIP_URL: string = 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb';
const GEOSITE_URL: string = 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat';

@Component
export struct SettingsView {
  @State s: AppSettings = SettingsStore.instance.settings;
  @State appState: AppState = AppState.instance;
  @State geoUpdating: boolean = false;

  private save(patch: Partial<AppSettings>, toastMsg: string): void {
    SettingsStore.instance.update(patch);
    this.s = SettingsStore.instance.settings;
    if (toastMsg.length > 0) {
      promptAction.showToast({ message: toastMsg });
    }
  }

  private async switchMode(mode: string): Promise<void> {
    this.save({ mode: mode }, '');
    if (this.appState.coreRunning) {
      try {
        const patch: Record<string, string> = { mode: mode };
        await ApiClient.instance.patchConfigs(patch);
        this.appState.mode = mode;
        promptAction.showToast({ message: `已切换为${mode === 'rule' ? '规则' : mode === 'global' ? '全局' : '直连'}模式` });
      } catch (e) {
        promptAction.showToast({ message: `切换失败：${e instanceof Error ? e.message : String(e)}` });
      }
    } else {
      promptAction.showToast({ message: '已保存，重启连接后生效' });
    }
  }

  @Builder
  ModeRadio(label: string, mode: string) {
    Text(label)
      .fontSize(HDimens.FONT_BODY)
      .fontColor(this.s.mode === mode ? Color.White : HColor.TEXT_SECONDARY)
      .backgroundColor(this.s.mode === mode ? HColor.BRAND : HColor.DIVIDER)
      .borderRadius(10)
      .padding({ top: 8, bottom: 8 })
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .onClick(() => {
        this.switchMode(mode);
      });
  }

  @Builder
  SettingRow(label: string, @Builder content: () => void) {
    Row() {
      Text(label)
        .fontSize(HDimens.FONT_BODY)
        .fontColor(HColor.TEXT_PRIMARY)
        .layoutWeight(1);
      content();
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  GroupCard(@Builder content: () => void) {
    Column() {
      content();
    }
    .width('100%')
    .padding({ left: HDimens.CARD_PADDING, right: HDimens.CARD_PADDING, top: 4, bottom: 4 })
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(HDimens.CARD_RADIUS)
    .border({ width: 1, color: HColor.CARD_BORDER });
  }

  @Builder
  LogRadio(label: string, value: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.s.logLevel === value ? Color.White : HColor.TEXT_SECONDARY)
      .backgroundColor(this.s.logLevel === value ? HColor.BRAND : HColor.DIVIDER)
      .borderRadius(8)
      .padding({ top: 6, bottom: 6 })
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .onClick(() => {
        this.save({ logLevel: value }, '已保存');
      });
  }

  private async updateGeoAssets(): Promise<void> {
    if (this.geoUpdating) {
      return;
    }
    this.geoUpdating = true;
    promptAction.showToast({ message: '正在下载 GEO 数据…' });
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await this.downloadToFile(GEOIP_URL, `${ctx.filesDir}/geoip.metadb`);
      await this.downloadToFile(GEOSITE_URL, `${ctx.filesDir}/geosite.dat`);
      promptAction.showToast({ message: 'GEO 数据已更新' });
    } catch (e) {
      promptAction.showToast({ message: `下载失败：${e instanceof Error ? e.message : String(e)}` });
    } finally {
      this.geoUpdating = false;
    }
  }

  private async downloadToFile(url: string, path: string): Promise<void> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 30000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (resp.responseCode >= 400) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      const buf: ArrayBuffer = resp.result as ArrayBuffer;
      const fd: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(fd.fd, buf);
      } finally {
        fs.closeSync(fd);
      }
    } finally {
      req.destroy();
    }
  }

  build() {
    Scroll() {
      Column({ space: HDimens.CARD_GAP }) {
        Row() {
          Text('设置')
            .fontSize(HDimens.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(HColor.TEXT_PRIMARY);
        }
        .width('100%')
        .padding({ top: 12, bottom: 4 });

        // 代理
        SectionHeader({ title: '代理' });
        this.GroupCard(() => {
          Column({ space: 4 }) {
            this.SettingRow('运行模式', () => {
              Row({ space: 8 }) {
                this.ModeRadio('规则', 'rule');
                this.ModeRadio('全局', 'global');
                this.ModeRadio('直连', 'direct');
              }
              .width('55%');
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('混合端口', () => {
              TextInput({ text: this.s.mixedPort.toString() })
                .type(InputType.Number)
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .borderRadius(8)
                .width(110)
                .height(36)
                .textAlign(TextAlign.End)
                .onChange((v: string) => {
                  const n: number = Number(v);
                  if (!isNaN(n) && n > 0 && n < 65536) {
                    this.save({ mixedPort: n }, '');
                  }
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('延迟测试 URL', () => {
              TextInput({ text: this.s.delayTestUrl })
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .placeholderColor(HColor.TEXT_TERTIARY)
                .borderRadius(8)
                .width('55%')
                .height(36)
                .onChange((v: string) => {
                  this.save({ delayTestUrl: v }, '');
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('允许局域网', () => {
              Toggle({ type: ToggleType.Switch, isOn: this.s.allowLan })
                .selectedColor(HColor.BRAND)
                .onChange((isOn: boolean) => {
                  this.save({ allowLan: isOn }, '已保存，重启连接后生效');
                });
            });
          }
          .width('100%');
        });

        // VPN 隧道
        SectionHeader({ title: 'VPN 隧道' });
        this.GroupCard(() => {
          Column({ space: 4 }) {
            this.SettingRow('MTU', () => {
              TextInput({ text: this.s.tunMtu.toString() })
                .type(InputType.Number)
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .borderRadius(8)
                .width(110)
                .height(36)
                .textAlign(TextAlign.End)
                .onChange((v: string) => {
                  const n: number = Number(v);
                  if (!isNaN(n) && n >= 576 && n <= 65535) {
                    this.save({ tunMtu: n }, '');
                  }
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('DNS 服务器', () => {
              TextInput({ text: this.s.dnsServers.join(',') })
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .placeholderColor(HColor.TEXT_TERTIARY)
                .borderRadius(8)
                .width('55%')
                .height(36)
                .onChange((v: string) => {
                  const arr: string[] = v.split(',').map((it: string): string => it.trim()).filter((it: string): boolean => it.length > 0);
                  if (arr.length > 0) {
                    this.save({ dnsServers: arr }, '');
                  }
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('IPv6', () => {
              Toggle({ type: ToggleType.Switch, isOn: this.s.ipv6 })
                .selectedColor(HColor.BRAND)
                .onChange((isOn: boolean) => {
                  this.save({ ipv6: isOn }, '已保存，重启连接后生效');
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('绕过私网', () => {
              Toggle({ type: ToggleType.Switch, isOn: this.s.bypassPrivateNetworks })
                .selectedColor(HColor.BRAND)
                .onChange((isOn: boolean) => {
                  this.save({ bypassPrivateNetworks: isOn }, '已保存，重启连接后生效');
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('分应用代理', () => {
              Row() {
                Text(this.s.perApp.mode === PerAppMode.Off ? '关闭'
                  : this.s.perApp.mode === PerAppMode.AllowList
                    ? `白名单 (${this.s.perApp.packages.length})`
                    : `黑名单 (${this.s.perApp.packages.length})`)
                  .fontSize(HDimens.FONT_CAPTION)
                  .fontColor(HColor.TEXT_SECONDARY);
                Text(' ›')
                  .fontSize(HDimens.FONT_BODY)
                  .fontColor(HColor.TEXT_TERTIARY);
              }
              .onClick(() => {
                router.pushUrl({ url: 'pages/AppProxyPage' });
              });
            });
          }
          .width('100%');
        });

        // 内核
        SectionHeader({ title: '内核' });
        this.GroupCard(() => {
          Column({ space: 4 }) {
            Column() {
              Text('日志级别')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 8 });
              Row({ space: 6 }) {
                this.LogRadio('错误', 'error');
                this.LogRadio('警告', 'warning');
                this.LogRadio('信息', 'info');
                this.LogRadio('调试', 'debug');
              }
              .width('100%');
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('API 端口', () => {
              TextInput({ text: this.s.apiPort.toString() })
                .type(InputType.Number)
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .borderRadius(8)
                .width(110)
                .height(36)
                .textAlign(TextAlign.End)
                .onChange((v: string) => {
                  const n: number = Number(v);
                  if (!isNaN(n) && n > 0 && n < 65536) {
                    this.save({ apiPort: n }, '');
                  }
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('API 密钥', () => {
              TextInput({ placeholder: '可选' })
                .backgroundColor(HColor.DIVIDER)
                .fontColor(HColor.TEXT_PRIMARY)
                .placeholderColor(HColor.TEXT_TERTIARY)
                .borderRadius(8)
                .width('55%')
                .height(36)
                .type(InputType.Password)
                .onChange((v: string) => {
                  this.save({ apiSecret: v }, '');
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('更新 GEO 数据', () => {
              Text(this.geoUpdating ? '下载中…' : '更新')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(this.geoUpdating ? HColor.TEXT_TERTIARY : HColor.BRAND)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(HColor.DIVIDER)
                .borderRadius(10)
                .onClick(() => {
                  this.updateGeoAssets();
                });
            });
          }
          .width('100%');
        });

        // 应用
        SectionHeader({ title: '应用' });
        this.GroupCard(() => {
          Column({ space: 4 }) {
            this.SettingRow('启动时自动连接', () => {
              Toggle({ type: ToggleType.Switch, isOn: this.s.connectOnLaunch })
                .selectedColor(HColor.BRAND)
                .onChange((isOn: boolean) => {
                  this.save({ connectOnLaunch: isOn }, '已保存');
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('查看规则', () => {
              Text('›')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_TERTIARY)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/RulesPage' });
                });
            });
            Divider().color(HColor.DIVIDER);

            this.SettingRow('查看日志', () => {
              Text('›')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_TERTIARY)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/LogsPage' });
                });
            });
          }
          .width('100%');
        });

        // 关于
        SectionHeader({ title: '关于' });
        this.GroupCard(() => {
          Column({ space: 4 }) {
            this.SettingRow('关于 HClash', () => {
              Text('›')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_TERTIARY)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/AboutPage' });
                });
            });
            Divider().color(HColor.DIVIDER);
            this.SettingRow('版本', () => {
              Text('1.0.0')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_SECONDARY);
            });
          }
          .width('100%');
        });

        Column().height(24);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }
}
