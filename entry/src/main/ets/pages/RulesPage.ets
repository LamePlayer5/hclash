import router from '@ohos.router';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient } from '../services/ApiClient';
import { RuleInfo, RulesResp } from '../models/ClashTypes';
import { EmptyState } from '../components/EmptyState';

@Entry
@Component
struct RulesPage {
  @State appState: AppState = AppState.instance;
  @State rules: RuleInfo[] = [];
  @State filtered: RuleInfo[] = [];
  @State keyword: string = '';
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.loadRules();
  }

  async loadRules(): Promise<void> {
    if (!this.appState.coreRunning) {
      this.rules = [];
      this.filtered = [];
      return;
    }
    this.loading = true;
    try {
      const resp: RulesResp = await ApiClient.instance.getRules();
      this.rules = resp.rules;
      this.applyFilter();
    } catch (e) {
      this.rules = [];
      this.filtered = [];
    } finally {
      this.loading = false;
    }
  }

  private applyFilter(): void {
    const kw: string = this.keyword.toLowerCase().trim();
    if (kw.length === 0) {
      this.filtered = this.rules;
      return;
    }
    this.filtered = this.rules.filter((r: RuleInfo): boolean => {
      return r.type.toLowerCase().includes(kw)
        || r.payload.toLowerCase().includes(kw)
        || r.proxy.toLowerCase().includes(kw);
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
        Text('规则')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
        Blank();
        Text(`${this.filtered.length}`)
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.TEXT_SECONDARY);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 8 });

      // 搜索框
      TextInput({ placeholder: '搜索规则（类型/内容/策略）' })
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

      if (!this.appState.coreRunning) {
        EmptyState({ title: '内核未运行', desc: '请先在首页启动连接，再查看规则列表' });
      } else if (this.filtered.length === 0) {
        EmptyState({ title: '暂无规则', desc: this.keyword.length > 0 ? '没有匹配的规则' : '当前配置没有加载任何规则' });
      } else {
        List({ space: 1 }) {
          ForEach(this.filtered, (r: RuleInfo, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}`)
                  .fontSize(11)
                  .fontColor(HColor.TEXT_TERTIARY)
                  .width(36)
                  .textAlign(TextAlign.End)
                  .margin({ right: 10 });

                Column() {
                  Text(r.payload)
                    .fontSize(14)
                    .fontColor(HColor.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                  Text(`${r.type} → ${r.proxy}`)
                    .fontSize(11)
                    .fontColor(HColor.TEXT_SECONDARY)
                    .maxLines(1)
                    .margin({ top: 2 });
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%')
              .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 10, bottom: 10 })
              .backgroundColor(HColor.PAGE_BG);
            }
          }, (r: RuleInfo, index: number) => `${index}-${r.payload}-${r.proxy}`);
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
