import { promptAction } from '@kit.ArkUI';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ApiClient } from '../services/ApiClient';
import { ProxiesResp, ProxyInfo, DEFAULT_DELAY_URL, DEFAULT_DELAY_TIMEOUT } from '../models/ClashTypes';
import { ProxyGroupCard } from '../components/ProxyGroupCard';
import { EmptyState } from '../components/EmptyState';
import { SettingsStore } from '../services/SettingsStore';

/** 内置代理，不属于用户代理组 */
const BUILTIN_PROXIES: string[] = ['DIRECT', 'REJECT', 'REJECT-DROP', 'PASS', 'COMPATIBLE'];

function isGroup(p: ProxyInfo): boolean {
  return p.all !== undefined && p.all !== null && p.all.length > 0;
}

function typeRank(t: string): number {
  if (t === 'Selector') {
    return 0;
  }
  if (t === 'URLTest' || t === 'Fallback' || t === 'LoadBalance') {
    return 1;
  }
  return 2;
}

@Component
export struct ProxiesView {
  @State appState: AppState = AppState.instance;
  @State groups: ProxyInfo[] = [];
  @State delays: Record<string, number> = {};
  @State expanded: Record<string, boolean> = {};
  @State loading: boolean = false;
  @State testingAll: boolean = false;
  @State testProgress: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  async refresh(): Promise<void> {
    if (!this.appState.coreRunning) {
      this.groups = [];
      return;
    }
    this.loading = true;
    try {
      const proxies: Record<string, ProxyInfo> = await ApiClient.instance.getProxies();
      const groups: ProxyInfo[] = [];
      const delays: Record<string, number> = {};
      const names: string[] = Object.keys(proxies);
      for (const n of names) {
        const p: ProxyInfo = proxies[n];
        // 提取历史延迟
        if (p.history !== undefined && p.history !== null && p.history.length > 0) {
          const last = p.history[p.history.length - 1];
          delays[n] = last.delay;
        } else {
          delays[n] = 0;
        }
        if (isGroup(p) && BUILTIN_PROXIES.indexOf(n) < 0) {
          groups.push(p);
        }
      }
      groups.sort((a: ProxyInfo, b: ProxyInfo): number => {
        const ra: number = typeRank(a.type);
        const rb: number = typeRank(b.type);
        if (ra !== rb) {
          return ra - rb;
        }
        return a.name.localeCompare(b.name);
      });
      this.groups = groups;
      this.delays = delays;
      // 统计节点数
      let count: number = 0;
      for (const g of groups) {
        if (g.all !== undefined && g.all !== null) {
          count += g.all.length;
        }
      }
      this.appState.proxyCount = count;
    } catch (e) {
      promptAction.showToast({ message: `获取代理失败：${e instanceof Error ? e.message : String(e)}` });
    } finally {
      this.loading = false;
    }
  }

  /** 测试单个代理组内全部节点延迟 */
  async testGroup(group: ProxyInfo): Promise<void> {
    if (!this.appState.coreRunning || group.all === undefined || group.all === null) {
      return;
    }
    const url: string = SettingsStore.instance.settings.delayTestUrl;
    const nodes: string[] = group.all;
    const results: string[] = await Promise.all(nodes.map(async (node: string): Promise<string> => {
      const d: number = await ApiClient.instance.getProxyDelay(node, url, DEFAULT_DELAY_TIMEOUT);
      this.delays[node] = d;
      return node;
    }));
    // 触发 UI 刷新
    this.delays = Object.assign({}, this.delays) as Record<string, number>;
  }

  async testAll(): Promise<void> {
    if (this.testingAll || !this.appState.coreRunning) {
      return;
    }
    this.testingAll = true;
    try {
      for (let i = 0; i < this.groups.length; i++) {
        const g: ProxyInfo = this.groups[i];
        this.testProgress = `${i + 1}/${this.groups.length} ${g.name}`;
        await this.testGroup(g);
      }
      this.testProgress = '';
    } finally {
      this.testingAll = false;
    }
  }

  async selectNode(group: ProxyInfo, node: string): Promise<void> {
    try {
      await ApiClient.instance.selectProxy(group.name, node);
      group.now = node;
      // 触发 UI 刷新
      this.groups = this.groups.slice() as ProxyInfo[];
    } catch (e) {
      promptAction.showToast({ message: `切换失败：${e instanceof Error ? e.message : String(e)}` });
    }
  }

  build() {
    Column() {
      // 顶部工具行
      Row() {
        Text('代理')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
        Blank();
        if (this.testProgress.length > 0) {
          Text(this.testProgress)
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(HColor.TEXT_SECONDARY)
            .margin({ right: 8 });
        }
        Text(this.testingAll ? '测速中…' : '全部测速')
          .fontSize(HDimens.FONT_BODY)
          .fontColor(this.testingAll ? HColor.TEXT_TERTIARY : HColor.BRAND)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(12)
          .onClick(() => {
            this.testAll();
          });
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 8 });

      if (!this.appState.coreRunning) {
        EmptyState({
          title: '内核未运行',
          desc: '请先在首页启动连接，再查看代理节点'
        });
      } else if (this.groups.length === 0) {
        EmptyState({
          title: '暂无代理组',
          desc: '当前配置中没有可管理的代理组，请检查订阅内容',
          actionText: '刷新',
          onAction: () => {
            this.refresh();
          }
        });
      } else {
        // 列表（下拉刷新）
        Refresh({ refreshing: this.loading }) {
          List({ space: HDimens.CARD_GAP }) {
            ForEach(this.groups, (g: ProxyInfo) => {
              ListItem() {
                ProxyGroupCard({
                  groupName: g.name,
                  groupType: g.type,
                  nodes: g.all !== undefined && g.all !== null ? g.all : [],
                  current: g.now !== undefined && g.now !== null ? g.now : '',
                  delays: this.delays,
                  expanded: this.expanded[g.name] === true,
                  onToggle: () => {
                    this.expanded[g.name] = !(this.expanded[g.name] === true);
                    this.expanded = Object.assign({}, this.expanded) as Record<string, boolean>;
                  },
                  onSelect: (node: string) => {
                    this.selectNode(g, node);
                  },
                  onTest: () => {
                    this.testGroup(g);
                  }
                });
              }
            }, (g: ProxyInfo) => `${g.name}-${g.type}-${g.now !== undefined ? g.now : ''}-${this.expanded[g.name] === true ? 'e' : 'c'}`);
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off);
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING })
        .onRefreshing(() => {
          this.refresh();
        });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
