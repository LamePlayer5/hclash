import { HColor, HDimens } from '../theme/Theme';

/**
 * 空状态占位：居中的"空盒子"图形（基础图形组合，无媒体资源）+ 标题 + 描述 + 可选按钮。
 */
@Component
export struct EmptyState {
  /** 标题 */
  @Prop title: string = '';
  /** 描述，为空则不显示 */
  @Prop desc: string = '';
  /** 按钮文字，为空则不显示按钮 */
  @Prop actionText: string = '';
  /** 按钮点击回调 */
  onAction: () => void = () => {};

  build() {
    Column() {
      // 64x64 浅灰圆形底 + 简化"空盒子"（盒盖横条 + 描边盒身）
      Stack() {
        Circle()
          .width(64)
          .height(64)
          .fill(HColor.CARD_BORDER);
        Column() {
          // 盒盖
          Row()
            .width(26)
            .height(6)
            .backgroundColor(HColor.TEXT_TERTIARY)
            .borderRadius(2);
          // 盒身
          Column()
            .width(32)
            .height(18)
            .border({ width: 2, color: HColor.TEXT_TERTIARY })
            .borderRadius(3)
            .margin({ top: 3 });
        }
        .alignItems(HorizontalAlign.Center);
      }
      .width(64)
      .height(64)
      .margin({ bottom: HDimens.CARD_GAP });

      Text(this.title)
        .fontSize(HDimens.FONT_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(HColor.TEXT_PRIMARY)
        .textAlign(TextAlign.Center);

      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
          .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING });
      }

      if (this.actionText.length > 0) {
        Button(this.actionText)
          .type(ButtonType.Normal)
          .backgroundColor(HColor.BRAND)
          .fontColor(HColor.TEXT_PRIMARY)
          .fontSize(HDimens.FONT_BODY)
          .borderRadius(HDimens.CARD_RADIUS)
          .height(40)
          .padding({ left: 24, right: 24 })
          .margin({ top: HDimens.PAGE_PADDING })
          .onClick((): void => {
            this.onAction();
          });
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 60, bottom: 60 });
  }
}
