import { HColor, HDimens } from '../theme/Theme';

/**
 * 区块标题行：左侧 16fp 半粗体标题，右侧可选品牌色操作文字，两端对齐。
 */
@Component
export struct SectionHeader {
  /** 区块标题 */
  @Prop title: string = '';
  /** 右侧操作文字，为空则不显示 */
  @Prop action: string = '';
  /** 操作文字点击回调 */
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(HDimens.FONT_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(HColor.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Blank();
      if (this.action.length > 0) {
        Text(this.action)
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.BRAND)
          .maxLines(1)
          .onClick((): void => {
            this.onAction();
          });
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ top: HDimens.CARD_GAP, bottom: HDimens.CARD_GAP });
  }
}
