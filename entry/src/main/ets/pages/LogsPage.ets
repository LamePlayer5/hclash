import router from '@ohos.router';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient, ClashWs } from '../services/ApiClient';
import { LogEntry } from '../models/ClashTypes';
import { EmptyState } from '../components/EmptyState';

const MAX_LOGS: number = 500;

function levelColor(level: string): Resource {
  if (level === 'error') {
    return HColor.RED;
  }
  if (level === 'warning') {
    return HColor.YELLOW;
  }
  if (level === 'info') {
    return HColor.BLUE;
  }
  return HColor.TEXT_TERTIARY;
}

@Entry
@Component
struct LogsPage {
  @State appState: AppState = AppState.instance;
  @State logs: LogEntry[] = [];
  @State level: string = 'info';
  @State paused: boolean = false;
  private ws: ClashWs | undefined = undefined;

  aboutToAppear(): void {
    if (this.appState.coreRunning) {
      this.openWs();
    }
  }

  aboutToDisappear(): void {
    if (this.ws !== undefined) {
      this.ws.close();
      this.ws = undefined;
    }
  }

  private openWs(): void {
    if (this.ws !== undefined) {
      this.ws.close();
      this.ws = undefined;
    }
    this.ws = ApiClient.instance.openLogsWs(this.level, (entry: LogEntry) => {
      if (!this.paused) {
        const next: LogEntry[] = [entry].concat(this.logs);
        this.logs = next.length > MAX_LOGS ? next.slice(0, MAX_LOGS) : next;
      }
    }, () => {
      this.ws = undefined;
    });
  }

  private switchLevel(level: string): void {
    this.level = level;
    this.logs = [];
    this.openWs();
  }

  @Builder
  LevelButton(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.level === value ? Color.White : HColor.TEXT_SECONDARY)
      .backgroundColor(this.level === value ? HColor.BRAND : HColor.CARD_BG)
      .borderRadius(8)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .onClick(() => {
        this.switchLevel(value);
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
        Text('运行日志')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 8 });

      // 工具行
      Row({ space: 6 }) {
        this.LevelButton('错误', 'error');
        this.LevelButton('警告', 'warning');
        this.LevelButton('信息', 'info');
        this.LevelButton('调试', 'debug');
        Blank();
        Text(this.paused ? '继续' : '暂停')
          .fontSize(12)
          .fontColor(this.paused ? HColor.GREEN : HColor.YELLOW)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(8)
          .onClick(() => {
            this.paused = !this.paused;
          });
        Text('清空')
          .fontSize(12)
          .fontColor(HColor.RED)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(8)
          .onClick(() => {
            this.logs = [];
          });
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, bottom: 8 });

      if (!this.appState.coreRunning) {
        EmptyState({ title: '内核未运行', desc: '请先在首页启动连接，再查看运行日志' });
      } else if (this.logs.length === 0) {
        EmptyState({ title: '暂无日志', desc: `等待 ${this.level} 级别日志…` });
      } else {
        List({ space: 1 }) {
          ForEach(this.logs, (entry: LogEntry, index: number) => {
            ListItem() {
              Row() {
                Text(entry.type.toUpperCase())
                  .fontSize(9)
                  .fontColor(levelColor(entry.type))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .backgroundColor('#2230363D')
                  .margin({ right: 8 });

                Text(entry.payload)
                  .fontSize(11)
                  .fontColor(HColor.TEXT_PRIMARY)
                  .layoutWeight(1);
              }
              .width('100%')
              .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 6, bottom: 6 })
              .alignItems(VerticalAlign.Top);
            }
          }, (entry: LogEntry, index: number) => `${index}-${entry.payload.substring(0, 24)}`);
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
