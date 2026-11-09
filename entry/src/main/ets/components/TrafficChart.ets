import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { TrafficFrame } from '../models/ClashTypes';
import { formatSpeed } from '../utils/Format';

/** 上行折线颜色（Canvas 只接受字符串色值），对应 HColor.BLUE */
const UP_LINE_COLOR: string = '#58A6FF';
/** 下行折线颜色，对应 HColor.GREEN */
const DOWN_LINE_COLOR: string = '#3FB950';
/** 网格虚线颜色，对应 HColor.CARD_BORDER */
const GRID_COLOR: string = '#30363D';
/** 峰值标注文字颜色，对应 HColor.TEXT_SECONDARY */
const PEAK_TEXT_COLOR: string = '#8B949E';
/** 采样窗口（秒），与 AppState.trafficHistory 长度一致 */
const WINDOW_SECONDS: number = 60;
/** Y 轴最小量程（1KB/s），防止除零 */
const MIN_Y_MAX: number = 1024;

/**
 * 实时流量折线图：最近 60 秒上/下行速率，每秒自动重绘。
 */
@Component
export struct TrafficChart {
  /** 图表高度 */
  @Prop heightValue: number = 150;
  /** 刷新节拍：每秒 +1，驱动卡片重渲染 */
  @State private tick: number = 0;
  private timerId: number = -1;
  private chartReady: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.timerId = setInterval((): void => {
      this.tick = this.tick + 1;
      this.drawChart();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 重绘整个图表 */
  private drawChart(): void {
    if (!this.chartReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);

    const history: TrafficFrame[] = AppState.instance.trafficHistory;

    // 历史峰值与 Y 轴上限：峰值的 1.2 倍，最小 1KB/s 防除零
    let peak: number = 0;
    for (let i: number = 0; i < history.length; i++) {
      const f: TrafficFrame = history[i];
      if (f.up > peak) {
        peak = f.up;
      }
      if (f.down > peak) {
        peak = f.down;
      }
    }
    let yMax: number = peak * 1.2;
    if (yMax < MIN_Y_MAX) {
      yMax = MIN_Y_MAX;
    }

    const padL: number = 4;
    const padR: number = 4;
    const padT: number = 22;
    const padB: number = 6;
    const plotW: number = w - padL - padR;
    const plotH: number = h - padT - padB;
    if (plotW <= 0 || plotH <= 0) {
      return;
    }

    // 3 条横向虚线网格
    ctx.strokeStyle = GRID_COLOR;
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    for (let g: number = 1; g <= 3; g++) {
      const gy: number = padT + (plotH * g) / 4;
      ctx.beginPath();
      ctx.moveTo(padL, gy);
      ctx.lineTo(w - padR, gy);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    // 两条折线（最新数据靠右）
    this.drawLine(history, true, UP_LINE_COLOR, yMax, plotW, plotH, padL, padT);
    this.drawLine(history, false, DOWN_LINE_COLOR, yMax, plotW, plotH, padL, padT);

    // 左上角峰值标注
    ctx.font = '10vp sans-serif';
    ctx.fillStyle = PEAK_TEXT_COLOR;
    ctx.textAlign = 'left';
    ctx.fillText(`峰值 ${formatSpeed(peak)}`, padL, padT - 10);
  }

  /** 绘制单条折线，x 轴按 60 秒窗口右对齐 */
  private drawLine(history: TrafficFrame[], isUp: boolean, color: string, yMax: number,
    plotW: number, plotH: number, padL: number, padT: number): void {
    const n: number = history.length;
    if (n === 0) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const step: number = plotW / (WINDOW_SECONDS - 1);
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    for (let i: number = 0; i < n; i++) {
      const f: TrafficFrame = history[i];
      const v: number = isUp ? f.up : f.down;
      const x: number = padL + plotW - (n - 1 - i) * step;
      let ratio: number = v / yMax;
      if (ratio > 1) {
        ratio = 1;
      }
      const y: number = padT + plotH * (1 - ratio);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();
  }

  build() {
    Column() {
      Row() {
        Column()
          .width(4)
          .height(14)
          .borderRadius(2)
          .backgroundColor(HColor.BRAND)
          .margin({ right: 8 });
        Text('实时流量')
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.TEXT_SECONDARY);
        Blank();
        // 当前速率图例（tick 每秒驱动刷新）
        Text(`↑ ${formatSpeed(AppState.instance.upSpeed)}`)
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.BLUE);
        Text(`↓ ${formatSpeed(AppState.instance.downSpeed)}`)
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.GREEN)
          .margin({ left: HDimens.CARD_GAP });
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      .margin({ bottom: 8 });

      // Canvas 默认背景透明，每帧 clearRect 重绘
      Canvas(this.ctx)
        .width('100%')
        .height(this.heightValue)
        .onReady((): void => {
          this.chartReady = true;
          this.drawChart();
        });
    }
    .width('100%')
    .padding(HDimens.CARD_PADDING)
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(HDimens.CARD_RADIUS)
    .border({ width: 1, color: HColor.CARD_BORDER });
  }
}
