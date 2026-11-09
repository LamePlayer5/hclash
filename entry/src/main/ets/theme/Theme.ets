/**
 * HClash 全局主题常量。
 * 深色优先设计（对齐 Clash Verge 的默认观感），浅色模式预留。
 */

export class HColor {
  static readonly BRAND: Resource = $r('app.color.brand');
  static readonly BRAND_DARK: Resource = $r('app.color.brand_dark');
  static readonly PAGE_BG: Resource = $r('app.color.page_background');
  static readonly CARD_BG: Resource = $r('app.color.card_background');
  static readonly CARD_BORDER: Resource = $r('app.color.card_border');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.text_primary');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly TEXT_TERTIARY: Resource = $r('app.color.text_tertiary');
  static readonly GREEN: Resource = $r('app.color.accent_green');
  static readonly YELLOW: Resource = $r('app.color.accent_yellow');
  static readonly RED: Resource = $r('app.color.accent_red');
  static readonly BLUE: Resource = $r('app.color.accent_blue');
  static readonly DIVIDER: Resource = $r('app.color.divider');
  static readonly TAB_BAR_BG: Resource = $r('app.color.tab_bar_background');
}

export class HDimens {
  static readonly PAGE_PADDING: number = 16;
  static readonly CARD_RADIUS: number = 16;
  static readonly CARD_PADDING: number = 14;
  static readonly CARD_GAP: number = 12;
  static readonly FONT_TITLE: number = 20;
  static readonly FONT_SUBTITLE: number = 16;
  static readonly FONT_BODY: number = 14;
  static readonly FONT_CAPTION: number = 12;
}

/** 根据延迟值返回对应的颜色资源（绿/黄/红/灰） */
export function delayColor(delay: number): Resource {
  if (delay <= 0) {
    return HColor.TEXT_TERTIARY;
  }
  if (delay < 200) {
    return HColor.GREEN;
  }
  if (delay < 500) {
    return HColor.YELLOW;
  }
  return HColor.RED;
}
