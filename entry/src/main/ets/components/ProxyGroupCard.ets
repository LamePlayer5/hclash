import { HColor, HDimens } from '../theme/Theme';
import { ProxyNodeItem } from './ProxyNodeItem';

/** 当前节点名最大显示长度，超出截断加省略号 */
const CURRENT_NAME_MAX: number = 20;

/**
 * 代理组卡片：头部为组名/类型/数量/当前节点 + 测速按钮 + 展开箭头，
 * 展开后列出组内全部节点（ProxyNodeItem）。
 */
@Component
export struct ProxyGroupCard {
  /** 组名 */
  @Prop groupName: string = '';
  /** 组类型（Selector/URLTest/Fallback/LoadBalance） */
  @Prop groupType: string = '';
  /** 组内节点名列表 */
  @Prop nodes: string[] = [];
  /** 当前选中节点名 */
  @Prop current: string = '';
  /** 节点名 → 延迟（可能缺键，访问前判 undefined） */
  @Prop delays: Record<string, number> = {};
  /** 是否展开 */
  @Prop expanded: boolean = false;
  /** 展开/收起回调 */
  onToggle: () => void = () => {};
  /** 选中节点回调 */
  onSelect: (node: string) => void = () => {};
  /** 整组测速回调 */
  onTest: () => void = () => {};

  /** 节点延迟：delays 缺键时返回 0 */
  private delayOf(node: string): number {
    const d: number | undefined = this.delays[node];
    if (d === undefined) {
      return 0;
    }
    return d;
  }

  /** 超长节点名截断（最多 20 字符，超出加省略号） */
  private shortName(name: string): string {
    if (name.length > CURRENT_NAME_MAX) {
      return name.substring(0, CURRENT_NAME_MAX) + '…';
    }
    return name;
  }

  build() {
    Column() {
      // 头部
      Row() {
        Column() {
          Text(this.groupName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(HColor.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(`${this.groupType} · ${this.nodes.length} 节点`)
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(HColor.TEXT_SECONDARY)
            .margin({ top: 2 });
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        // 当前节点名（次要色，最多 20 字符）
        if (this.current.length > 0) {
          Text(this.shortName(this.current))
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(HColor.TEXT_SECONDARY)
            .maxLines(1)
            .margin({ right: HDimens.CARD_GAP });
        }

        // 测速小按钮
        Text('测速')
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.BRAND)
          .border({ width: 1, color: HColor.BRAND })
          .borderRadius(6)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .onClick((): void => {
            this.onTest();
          });

        // 展开箭头
        Text(this.expanded ? '▲' : '▼')
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.TEXT_TERTIARY)
          .margin({ left: HDimens.CARD_GAP });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick((): void => {
        this.onToggle();
      });

      // 展开的节点列表
      if (this.expanded) {
        Divider()
          .strokeWidth(0.5)
          .color(HColor.DIVIDER)
          .margin({ top: HDimens.CARD_GAP, bottom: 4 });
        Column() {
          ForEach(this.nodes, (node: string) => {
            ProxyNodeItem({
              name: node,
              proxyType: '',
              delay: this.delayOf(node),
              selected: node === this.current,
              udp: false,
              onClick: (): void => {
                this.onSelect(node);
              }
            });
          }, (node: string): string => node);
        }
        .width('100%');
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
