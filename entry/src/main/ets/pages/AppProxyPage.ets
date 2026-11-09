import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HColor, HDimens } from '../theme/Theme';
import { SettingsStore } from '../services/SettingsStore';
import { AppListService, InstalledApp } from '../services/AppListService';
import { PerAppMode, PerAppProxy } from '../models/Settings';
import { EmptyState } from '../components/EmptyState';

@Entry
@Component
struct AppProxyPage {
  @State mode: PerAppMode = SettingsStore.instance.settings.perApp.mode;
  @State packages: string[] = SettingsStore.instance.settings.perApp.packages.slice() as string[];
  @State apps: InstalledApp[] = [];
  @State filtered: InstalledApp[] = [];
  @State keyword: string = '';
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.loadApps();
  }

  async loadApps(): Promise<void> {
    this.loading = true;
    const apps: InstalledApp[] = await AppListService.instance.listInstalled(false);
    this.apps = apps;
    this.applyFilter();
    this.loading = false;
  }

  private applyFilter(): void {
    const kw: string = this.keyword.toLowerCase().trim();
    if (kw.length === 0) {
      this.filtered = this.apps;
      return;
    }
    this.filtered = this.apps.filter((a: InstalledApp): boolean => {
      return a.label.toLowerCase().includes(kw) || a.bundleName.toLowerCase().includes(kw);
    });
  }

  private togglePackage(bundleName: string): void {
    const idx: number = this.packages.indexOf(bundleName);
    if (idx >= 0) {
      this.packages.splice(idx, 1);
    } else {
      this.packages.push(bundleName);
    }
    this.packages = this.packages.slice() as string[];
  }

  private save(): void {
    const perApp: PerAppProxy = {
      mode: this.mode,
      packages: this.packages.slice() as string[]
    };
    SettingsStore.instance.updatePerApp(perApp);
    promptAction.showToast({ message: '已保存，重启连接后生效' });
    router.back();
  }

  @Builder
  ModeRadio(label: string, value: PerAppMode) {
    Text(label)
      .fontSize(HDimens.FONT_BODY)
      .fontColor(this.mode === value ? Color.White : HColor.TEXT_SECONDARY)
      .backgroundColor(this.mode === value ? HColor.BRAND : HColor.DIVIDER)
      .borderRadius(10)
      .padding({ top: 8, bottom: 8 })
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .onClick(() => {
        this.mode = value;
      });
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('‹ 返回')
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.BRAND)
          .padding({ left: 4, right: 12, top: 4, bottom: 4 })
          .onClick(() => {
            router.back();
          });
        Text('分应用代理')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 4 });

      Text('选择需要代理（或排除）的应用，保存后重启 VPN 生效。')
        .fontSize(HDimens.FONT_CAPTION)
        .fontColor(HColor.TEXT_TERTIARY)
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, bottom: 8 });

      // 模式选择
      Row({ space: 8 }) {
        this.ModeRadio('关闭', PerAppMode.Off);
        this.ModeRadio('仅代理选中', PerAppMode.AllowList);
        this.ModeRadio('排除选中', PerAppMode.BlockList);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, bottom: 8 });

      // 搜索框
      TextInput({ placeholder: '搜索应用名称或包名' })
        .backgroundColor(HColor.CARD_BG)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(12)
        .height(40)
        .margin({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, bottom: 8 })
        .onChange((v: string) => {
          this.keyword = v;
          this.applyFilter();
        });

      if (this.apps.length === 0) {
        EmptyState({
          title: '无法获取应用列表',
          desc: '需要 GET_INSTALLED_BUNDLE_LIST 权限，请在 DevEco Studio 签名配置中申请 ACL 授权后重试',
          actionText: '重试',
          onAction: () => {
            this.loadApps();
          }
        });
      } else {
        List({ space: 1 }) {
          ForEach(this.filtered, (a: InstalledApp) => {
            ListItem() {
              Row() {
                Column() {
                  Text(a.label)
                    .fontSize(HDimens.FONT_BODY)
                    .fontColor(HColor.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                  Text(a.bundleName)
                    .fontSize(10)
                    .fontColor(HColor.TEXT_TERTIARY)
                    .maxLines(1)
                    .margin({ top: 2 });
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Text(this.packages.indexOf(a.bundleName) >= 0 ? '✓' : '')
                  .fontSize(18)
                  .fontColor(HColor.BRAND)
                  .width(24)
                  .textAlign(TextAlign.Center);
              }
              .width('100%')
              .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 10, bottom: 10 })
              .onClick(() => {
                this.togglePackage(a.bundleName);
              });
            }
          }, (a: InstalledApp) => a.bundleName);
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
      }

      // 底部保存按钮
      Button('保存')
        .type(ButtonType.Normal)
        .backgroundColor(HColor.BRAND)
        .fontColor(Color.White)
        .width('100%')
        .height(48)
        .borderRadius(14)
        .margin({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 8, bottom: 16 })
        .onClick(() => {
          this.save();
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
