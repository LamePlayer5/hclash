import router from '@ohos.router';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';

@Entry
@Component
struct AboutPage {
  @State appState: AppState = AppState.instance;

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(HDimens.FONT_BODY)
        .fontColor(HColor.TEXT_SECONDARY)
        .layoutWeight(1);
      Text(value)
        .fontSize(HDimens.FONT_BODY)
        .fontColor(HColor.TEXT_PRIMARY);
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  Card(@Builder content: () => void) {
    Column() {
      content();
    }
    .width('100%')
    .padding(HDimens.CARD_PADDING)
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(HDimens.CARD_RADIUS)
    .border({ width: 1, color: HColor.CARD_BORDER });
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
        Text('关于')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 12 });

      Scroll() {
        Column({ space: HDimens.CARD_GAP }) {
          // 应用信息
          this.Card(() => {
            Column() {
              Text('HClash')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(HColor.TEXT_PRIMARY);
              Text('原生鸿蒙 Clash 客户端')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_SECONDARY)
                .margin({ top: 4 });

              Divider().color(HColor.DIVIDER).margin({ top: 12, bottom: 4 });

              this.InfoRow('版本', '1.0.0');
              this.InfoRow('内核版本', this.appState.coreVersion.length > 0 ? this.appState.coreVersion : '未运行');
              this.InfoRow('许可证', 'GPL-3.0');
            }
            .width('100%');
          });

          // 简介
          this.Card(() => {
            Column() {
              Text('简介')
                .fontSize(HDimens.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(HColor.TEXT_PRIMARY);
              Text('HClash 是一款原生鸿蒙（HarmonyOS NEXT）Clash 客户端，内核基于 Rust 实现的 clash-rs，支持 SS、VMess、VLESS、Trojan、Hysteria2、TUIC 等主流协议，界面与交互对标 Clash Verge，支持订阅管理、代理组切换、实时流量、连接管理、规则查看、分应用代理等功能。')
                .fontSize(HDimens.FONT_BODY)
                .fontColor(HColor.TEXT_SECONDARY)
                .margin({ top: 8 })
                .lineHeight(22);
            }
            .width('100%');
          });

          // 开源信息
          this.Card(() => {
            Column() {
              Text('开源信息')
                .fontSize(HDimens.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(HColor.TEXT_PRIMARY);
              this.InfoRow('GitHub', 'github.com/yourname/hclash');
              this.InfoRow('核心依赖', 'clash-rs (Rust)');
              this.InfoRow('平台', 'HarmonyOS NEXT (API 12+)');
              this.InfoRow('UI 框架', 'ArkTS / ArkUI');
            }
            .width('100%');
          });

          // 免责声明
          this.Card(() => {
            Column() {
              Text('免责声明')
                .fontSize(HDimens.FONT_SUBTITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(HColor.TEXT_PRIMARY);
              Text('本应用仅供学习与技术交流使用，请遵守当地法律法规。使用本应用产生的一切后果由用户自行承担。')
                .fontSize(HDimens.FONT_CAPTION)
                .fontColor(HColor.TEXT_TERTIARY)
                .margin({ top: 8 })
                .lineHeight(20);
            }
            .width('100%');
          });

          Column().height(24);
        }
        .width('100%')
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
