import { HColor, HDimens } from '../theme/Theme';
import { DashboardView } from '../views/DashboardView';
import { ProxiesView } from '../views/ProxiesView';
import { ProfilesView } from '../views/ProfilesView';
import { ConnectionsView } from '../views/ConnectionsView';
import { SettingsView } from '../views/SettingsView';

interface TabItem {
  title: string;
  icon: string;
  builder: () => void;
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;

  @Builder
  TabBuilder(title: string, icon: string, index: number) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(20)
        .fontColor(this.currentTab === index ? HColor.BRAND : HColor.TEXT_TERTIARY);
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? HColor.BRAND : HColor.TEXT_TERTIARY);
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    });
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          DashboardView();
        }
        .tabBar(this.TabBuilder('首页', '◎', 0));

        TabContent() {
          ProxiesView();
        }
        .tabBar(this.TabBuilder('代理', '⇄', 1));

        TabContent() {
          ProfilesView();
        }
        .tabBar(this.TabBuilder('订阅', '☰', 2));

        TabContent() {
          ConnectionsView();
        }
        .tabBar(this.TabBuilder('连接', '↯', 3));

        TabContent() {
          SettingsView();
        }
        .tabBar(this.TabBuilder('设置', '⚙', 4));
      }
      .barHeight(56)
      .barBackgroundColor(HColor.TAB_BAR_BG)
      .backgroundColor(HColor.PAGE_BG)
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
