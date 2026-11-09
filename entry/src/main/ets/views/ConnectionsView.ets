import { promptAction, AlertDialog } from '@kit.ArkUI';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient } from '../services/ApiClient';
import { ConnectionInfo, ConnectionsResp } from '../models/ClashTypes';
import { StatCard } from '../components/StatCard';
import { EmptyState } from '../components/EmptyState';
import { formatBytes, formatDuration } from '../utils/Format';

@Component
export struct ConnectionsView {
  @State appState: AppState = AppState.instance;
  @State conns: ConnectionInfo[] = [];
  @State upTotal: number = 0;
  @State downTotal: number = 0;
  private pollTimer: number = -1;

  aboutToAppear(): void {
    this.pollTimer = setInterval(() => {
      this.refresh();
    }, 2000);
    this.refresh();
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  async refresh(): Promise<void> {
    if (!this.appState.coreRunning) {
      this.conns = [];
      return;
    }
    try {
      const resp: ConnectionsResp = await ApiClient.instance.getConnections();
      this.upTotal = resp.uploadTotal;
      this.downTotal = resp.downloadTotal;
      const list: ConnectionInfo[] = resp.connections.slice() as ConnectionInfo[];
      list.sort((a: ConnectionInfo, b: ConnectionInfo): number => b.download - a.download);
      this.conns = list;
      this.appState.connectionCount = list.length;
    } catch (e) {
      // 轮询失败静默处理
    }
  }

  private closeOne(id: string): void {
    ApiClient.instance.closeConnection(id).then(() => {
      this.refresh();
    }).catch(() => {
    });
  }

  private closeAll(): void {
    AlertDialog.show({
      title: '关闭全部连接',
      message: '确定关闭当前所有活动连接吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '关闭全部',
        fontColor: HColor.RED,
        action: () => {
          ApiClient.instance.closeAllConnections().then(() => {
            this.refresh();
            promptAction.showToast({ message: '已关闭全部连接' });
          }).catch(() => {
            promptAction.showToast({ message: '操作失败' });
          });
        }
      }
    });
  }

  @Builder
  ConnRow(c: ConnectionInfo) {
    Row() {
      Column() {
        Text(c.metadata.host !== undefined && c.metadata.host !== null && c.metadata.host.length > 0
          ? c.metadata.host
          : `${c.metadata.destinationIP}:${c.metadata.destinationPort}`)
          .fontSize(14)
          .fontColor(HColor.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(c.chains.join(' ➜ '))
          .fontSize(11)
          .fontColor(HColor.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 });

        Text(`${c.rule}${c.rulePayload.length > 0 ? '/' + c.rulePayload : ''} · ${c.metadata.network.toUpperCase()} ${c.metadata.type}`)
          .fontSize(10)
          .fontColor(HColor.TEXT_TERTIARY)
          .maxLines(1)
          .margin({ top: 2 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Column({ space: 2 }) {
        Text(`↑ ${formatBytes(c.upload)}  ↓ ${formatBytes(c.download)}`)
          .fontSize(11)
          .fontColor(HColor.TEXT_SECONDARY);
        Text(formatDuration(Date.now() - new Date(c.start).getTime()))
          .fontSize(10)
          .fontColor(HColor.TEXT_TERTIARY);
      }
      .margin({ left: 8 })
      .alignItems(HorizontalAlign.End);

      Text('✕')
        .fontSize(14)
        .fontColor(HColor.RED)
        .padding({ left: 10, right: 2 })
        .onClick(() => {
          this.closeOne(c.id);
        });
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 10, bottom: 10 })
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(12)
    .alignItems(VerticalAlign.Top);
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('连接')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
        Text(` ${this.conns.length}`)
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.TEXT_SECONDARY);
        Blank();
        Text('关闭全部')
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.RED)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(12)
          .onClick(() => {
            this.closeAll();
          });
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 8 });

      if (!this.appState.coreRunning) {
        EmptyState({
          title: '内核未运行',
          desc: '请先在首页启动连接，再查看活动连接'
        });
      } else if (this.conns.length === 0) {
        EmptyState({
          title: '暂无活动连接',
          desc: '设备当前没有经过代理的网络请求'
        });
      } else {
        // 统计行
        Row({ space: HDimens.CARD_GAP }) {
          Column() {
            StatCard({ title: '上传总量', value: formatBytes(this.upTotal), sub: '', accent: HColor.BLUE });
          }.layoutWeight(1);
          Column() {
            StatCard({ title: '下载总量', value: formatBytes(this.downTotal), sub: '', accent: HColor.GREEN });
          }.layoutWeight(1);
        }
        .width('100%')
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, bottom: 8 });

        List({ space: 8 }) {
          ForEach(this.conns, (c: ConnectionInfo) => {
            ListItem() {
              this.ConnRow(c);
            }
          }, (c: ConnectionInfo) => c.id);
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING })
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
