import { HColor, HDimens, delayColor } from '../theme/Theme';
import { formatDelay } from '../utils/Format';

/**
 * 代理节点行：选中指示条 + 名称 + 类型/UDP 徽标 + 延迟，整行可点击。
 */
@Component
export struct ProxyNodeItem {
  /** 节点名 */
  @Prop name: string = '';
  /** 节点类型（如 SS/VMess/Trojan），为空则不显示徽标 */
  @Prop proxyType: string = '';
  /** 延迟毫秒数，0 表示未测/超时 */
  @Prop delay: number = 0;
  /** 是否当前选中 */
  @Prop selected: boolean = false;
  /** 是否显示 UDP 徽标 */
  @Prop udp: boolean = false;
  /** 整行点击回调 */
  onClick: () => void = () => {};

  build() {
    Row() {
      // 选中指示条：选中时品牌色，否则透明占位（用 opacity 保持占位宽度）
      Column()
        .width(3)
        .height(20)
        .borderRadius(2)
        .backgroundColor(HColor.BRAND)
        .opacity(this.selected ? 1 : 0)
        .margin({ right: 8 });

      // 节点名
      Text(this.name)
        .fontSize(HDimens.FONT_BODY)
        .fontColor(this.selected ? HColor.BRAND : HColor.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);

      // 类型徽标（小圆角灰底）
      if (this.proxyType.length > 0) {
        Text(this.proxyType)
          .fontSize(10)
          .fontColor(HColor.TEXT_SECONDARY)
          .backgroundColor(HColor.CARD_BORDER)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ left: 6 });
      }

      // UDP 徽标
      if (this.udp) {
        Text('UDP')
          .fontSize(10)
          .fontColor(HColor.TEXT_SECONDARY)
          .backgroundColor(HColor.CARD_BORDER)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ left: 6 });
      }

      // 延迟
      Text(formatDelay(this.delay))
        .fontSize(HDimens.FONT_CAPTION)
        .fontColor(delayColor(this.delay))
        .width(56)
        .textAlign(TextAlign.End)
        .margin({ left: 8 });
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
    .padding({ left: HDimens.CARD_GAP, right: HDimens.CARD_GAP })
    .onClick((): void => {
      this.onClick();
    });
  }
}
