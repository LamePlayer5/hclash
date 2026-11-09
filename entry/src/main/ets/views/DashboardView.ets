import { promptAction } from '@kit.ArkUI';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient } from '../services/ApiClient';
import { VpnService } from '../services/VpnService';
import { TrafficSampler } from '../services/TrafficSampler';
import { StatCard } from '../components/StatCard';
import { TrafficChart } from '../components/TrafficChart';
import { formatBytes, formatDuration, formatSpeed } from '../utils/Format';

@Component
export struct DashboardView {
  @State appState: AppState = AppState.instance;
  @State connecting: boolean = false;
  @State elapsed: string = '-';
  private tickTimer: number = -1;

  aboutToAppear(): void {
    if (this.appState.vpnRunning && this.appState.coreRunning) {
      TrafficSampler.instance.start();
    }
    this.tickTimer = setInterval(() => {
      this.refreshElapsed();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }
  }

  private refreshElapsed(): void {
    if (this.appState.startedAt > 0 && this.appState.vpnRunning) {
      this.elapsed = formatDuration(Date.now() - this.appState.startedAt);
    } else {
      this.elapsed = '-';
    }
  }

  private statusText(): string {
    if (this.appState.vpnRunning && this.appState.coreRunning) {
      return '已连接';
    }
    if (this.appState.vpnRunning && !this.appState.coreRunning) {
      return '已连接，内核启动中…';
    }
    return '未连接';
  }

  private async toggleConnection(): Promise<void> {
    if (this.connecting) {
      return;
    }
    this.connecting = true;
    try {
      if (this.appState.vpnRunning) {
        await VpnService.instance.stopVpn();
        TrafficSampler.instance.stop();
        promptAction.showToast({ message: '已断开连接' });
      } else {
        await VpnService.instance.startVpn();
        TrafficSampler.instance.start();
        promptAction.showToast({ message: '正在连接…' });
      }
      this.refreshElapsed();
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: msg });
    } finally {
      this.connecting = false;
    }
  }

  private async switchMode(mode: string): Promise<void> {
    if (!this.appState.coreRunning) {
      promptAction.showToast({ message: '内核未运行，请先连接' });
      return;
    }
    try {
      const patch: Record<string, string> = { mode: mode };
      await ApiClient.instance.patchConfigs(patch);
      this.appState.mode = mode;
      promptAction.showToast({ message: `已切换为${mode === 'rule' ? '规则' : mode === 'global' ? '全局' : '直连'}模式` });
    } catch (e) {
      promptAction.showToast({ message: `切换失败：${e instanceof Error ? e.message : String(e)}` });
    }
  }

  @Builder
  ModeButton(label: string, mode: string) {
    Text(label)
      .fontSize(HDimens.FONT_BODY)
      .fontColor(this.appState.mode === mode ? Color.White : HColor.TEXT_SECONDARY)
      .backgroundColor(this.appState.mode === mode ? HColor.BRAND : HColor.CARD_BG)
      .borderRadius(10)
      .padding({ top: 10, bottom: 10 })
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .onClick(() => {
        this.switchMode(mode);
      });
  }

  build() {
    Scroll() {
      Column({ space: HDimens.CARD_GAP }) {
        // 顶部大连接按钮
        Column() {
          Stack() {
            Circle()
              .width(84)
              .height(84)
              .fill(this.appState.vpnRunning && this.appState.coreRunning ? HColor.GREEN : HColor.BRAND);
            Text(this.connecting ? '…' : (this.appState.vpnRunning ? '停止' : '连接'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White);
          }
          .onClick(() => {
            this.toggleConnection();
          });

          Text(this.statusText())
            .fontSize(HDimens.FONT_BODY)
            .fontColor(this.appState.vpnRunning && this.appState.coreRunning ? HColor.GREEN : HColor.TEXT_SECONDARY)
            .margin({ top: 12 });
        }
        .width('100%')
        .padding({ top: 24, bottom: 16 })
        .alignItems(HorizontalAlign.Center);

        // 运行时长 + 当前配置
        Row({ space: HDimens.CARD_GAP }) {
          Column() {
            StatCard({ title: '运行时长', value: this.elapsed, sub: '', accent: HColor.GREEN });
          }.layoutWeight(1);

          Column() {
            StatCard({
              title: '当前配置',
              value: this.appState.activeProfileName.length > 0 ? this.appState.activeProfileName : '未选择',
              sub: '',
              accent: HColor.BLUE
            });
          }.layoutWeight(1);
        }
        .width('100%');

        // 模式切换
        Column() {
          Row({ space: 8 }) {
            this.ModeButton('规则', 'rule');
            this.ModeButton('全局', 'global');
            this.ModeButton('直连', 'direct');
          }
          .width('100%');
        }

        // 实时流量图表
        TrafficChart({ heightValue: 150 });

        // 流量信息
        Row({ space: HDimens.CARD_GAP }) {
          Column() {
            StatCard({
              title: '下载 ↓',
              value: formatSpeed(this.appState.downSpeed),
              sub: '总计 ' + formatBytes(this.appState.downTotal),
              accent: HColor.GREEN
            });
          }.layoutWeight(1);

          Column() {
            StatCard({
              title: '上传 ↑',
              value: formatSpeed(this.appState.upSpeed),
              sub: '总计 ' + formatBytes(this.appState.upTotal),
              accent: HColor.BLUE
            });
          }.layoutWeight(1);
        }
        .width('100%');

        // 状态
        Row({ space: HDimens.CARD_GAP }) {
          Column() {
            StatCard({ title: '活动连接', value: this.appState.connectionCount.toString(), sub: '', accent: HColor.YELLOW });
          }.layoutWeight(1);

          Column() {
            StatCard({
              title: '内核版本',
              value: this.appState.coreVersion.length > 0 ? this.appState.coreVersion : '-',
              sub: '',
              accent: HColor.BLUE
            });
          }.layoutWeight(1);
        }
        .width('100%');

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
