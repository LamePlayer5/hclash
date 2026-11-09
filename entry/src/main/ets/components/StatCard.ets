import { HColor, HDimens } from '../theme/Theme';

/**
 * 仪表盘统计卡片。
 * 小标题（次要色，左侧 4vp 强调竖条）+ 大数值（20fp 粗体）+ 可选底部说明。
 */
@Component
export struct StatCard {
  /** 小标题 */
  @Prop title: string = '';
  /** 大数值文本 */
  @Prop value: string = '';
  /** 底部说明，可选 */
  @Prop sub: string = '';
  /** 标题左侧竖条颜色，默认品牌色 */
  @Prop accent: Resource = HColor.BRAND;

  build() {
    Column() {
      Row() {
        // 标题左侧 4vp 竖条
        Column()
          .width(4)
          .height(14)
          .borderRadius(2)
          .backgroundColor(this.accent)
          .margin({ right: 8 });
        Text(this.title)
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .alignItems(VerticalAlign.Center);

      Text(this.value)
        .fontSize(HDimens.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(HColor.TEXT_PRIMARY)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.TEXT_TERTIARY)
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(HDimens.CARD_PADDING)
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(HDimens.CARD_RADIUS)
    .border({ width: 1, color: HColor.CARD_BORDER });
  }
}
