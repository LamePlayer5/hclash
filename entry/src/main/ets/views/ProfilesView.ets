import { promptAction, AlertDialog, CustomDialogController, Dialog } from '@kit.ArkUI';
import { HColor, HDimens } from '../theme/Theme';
import { AppState } from '../services/AppState';
import { ProfileManager } from '../services/ProfileManager';
import { Profile } from '../models/Profile';
import { SectionHeader } from '../components/SectionHeader';
import { EmptyState } from '../components/EmptyState';
import { formatDate, formatBytes, percentOf } from '../utils/Format';

@CustomDialog
struct AddSubscriptionDialog {
  controller?: CustomDialogController;
  onConfirm: (name: string, url: string, interval: number) => void = () => {};
  @State name: string = '';
  @State url: string = '';
  @State intervalStr: string = '0';
  @State saving: boolean = false;

  build() {
    Column({ space: 12 }) {
      Text('添加订阅')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(HColor.TEXT_PRIMARY);

      TextInput({ placeholder: '名称（可选）' })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(8)
        .height(44)
        .onChange((v: string) => {
          this.name = v;
        });

      TextInput({ placeholder: '订阅链接 (https://...)' })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(8)
        .height(44)
        .onChange((v: string) => {
          this.url = v;
        });

      TextInput({ placeholder: '自动更新间隔（分钟，0 = 手动）' })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(8)
        .height(44)
        .type(InputType.Number)
        .onChange((v: string) => {
          this.intervalStr = v;
        });

      Row({ space: 12 }) {
        Button('取消')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.DIVIDER)
          .fontColor(HColor.TEXT_SECONDARY)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
          });
        Button(this.saving ? '添加中…' : '添加')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.BRAND)
          .fontColor(Color.White)
          .layoutWeight(1)
          .enabled(!this.saving)
          .onClick(() => {
            if (this.url.length === 0) {
              promptAction.showToast({ message: '请输入订阅链接' });
              return;
            }
            this.saving = true;
            const interval: number = Number(this.intervalStr.length > 0 ? this.intervalStr : '0');
            this.onConfirm(this.name, this.url, isNaN(interval) ? 0 : interval);
          });
      }
      .width('100%')
      .margin({ top: 8 });
    }
    .padding(20)
    .width('100%');
  }
}

@CustomDialog
struct EditProfileDialog {
  controller?: CustomDialogController;
  profileName: string = '';
  profileInterval: number = 0;
  onConfirm: (name: string, interval: number) => void = () => {};
  @State name: string = '';
  @State intervalStr: string = '0';

  aboutToAppear(): void {
    this.name = this.profileName;
    this.intervalStr = this.profileInterval.toString();
  }

  build() {
    Column({ space: 12 }) {
      Text('编辑配置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(HColor.TEXT_PRIMARY);

      TextInput({ text: this.name })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .borderRadius(8)
        .height(44)
        .onChange((v: string) => {
          this.name = v;
        });

      TextInput({ text: this.intervalStr })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .borderRadius(8)
        .height(44)
        .type(InputType.Number)
        .onChange((v: string) => {
          this.intervalStr = v;
        });

      Row({ space: 12 }) {
        Button('取消')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.DIVIDER)
          .fontColor(HColor.TEXT_SECONDARY)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
          });
        Button('保存')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.BRAND)
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            const interval: number = Number(this.intervalStr.length > 0 ? this.intervalStr : '0');
            this.onConfirm(this.name, isNaN(interval) ? 0 : interval);
            this.controller?.close();
          });
      }
      .width('100%');
    }
    .padding(20)
    .width('100%');
  }
}

@CustomDialog
struct ImportLocalDialog {
  controller?: CustomDialogController;
  onConfirm: (name: string, content: string) => void = () => {};
  @State name: string = '';
  @State content: string = '';

  build() {
    Column({ space: 12 }) {
      Text('导入本地配置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(HColor.TEXT_PRIMARY);

      TextInput({ placeholder: '名称（可选）' })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(8)
        .height(44)
        .onChange((v: string) => {
          this.name = v;
        });

      TextArea({ placeholder: '粘贴 YAML 配置内容…' })
        .backgroundColor(HColor.DIVIDER)
        .fontColor(HColor.TEXT_PRIMARY)
        .placeholderColor(HColor.TEXT_TERTIARY)
        .borderRadius(8)
        .height(160)
        .onChange((v: string) => {
          this.content = v;
        });

      Row({ space: 12 }) {
        Button('取消')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.DIVIDER)
          .fontColor(HColor.TEXT_SECONDARY)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
          });
        Button('导入')
          .type(ButtonType.Normal)
          .backgroundColor(HColor.BRAND)
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            if (this.content.length === 0) {
              promptAction.showToast({ message: '请粘贴配置内容' });
              return;
            }
            this.onConfirm(this.name, this.content);
          });
      }
      .width('100%');
    }
    .padding(20)
    .width('100%');
  }
}

@Component
export struct ProfilesView {
  @State appState: AppState = AppState.instance;
  @State profiles: Profile[] = [];
  @State currentId: string = '';
  @State updating: Record<string, boolean> = {};
  private addDialogController: CustomDialogController = new CustomDialogController({
    builder: AddSubscriptionDialog({
      onConfirm: (name: string, url: string, interval: number) => {
        this.doAddUrl(name, url, interval);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  private importDialogController: CustomDialogController = new CustomDialogController({
    builder: ImportLocalDialog({
      onConfirm: (name: string, content: string) => {
        this.doImportLocal(name, content);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  private editDialogController: CustomDialogController = new CustomDialogController({
    builder: EditProfileDialog({
      profileName: '',
      profileInterval: 0,
      onConfirm: (name: string, interval: number) => {
        // placeholder, 每次打开前动态设置
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.profiles = ProfileManager.instance.list().slice() as Profile[];
    this.currentId = ProfileManager.instance.currentId();
  }

  private async doAddUrl(name: string, url: string, interval: number): Promise<void> {
    try {
      const p: Profile = await ProfileManager.instance.addFromUrl(name, url, interval);
      this.addDialogController.close();
      this.reload();
      promptAction.showToast({ message: `已添加订阅：${p.name}` });
    } catch (e) {
      promptAction.showToast({ message: `添加失败：${e instanceof Error ? e.message : String(e)}` });
    }
  }

  private doImportLocal(name: string, content: string): void {
    try {
      const p: Profile = ProfileManager.instance.addLocal(name, content);
      this.importDialogController.close();
      this.reload();
      promptAction.showToast({ message: `已导入配置：${p.name}` });
    } catch (e) {
      promptAction.showToast({ message: `导入失败：${e instanceof Error ? e.message : String(e)}` });
    }
  }

  private async doUpdate(p: Profile): Promise<void> {
    if (p.url.length === 0) {
      promptAction.showToast({ message: '本地配置无需更新' });
      return;
    }
    this.updating[p.id] = true;
    this.updating = Object.assign({}, this.updating) as Record<string, boolean>;
    try {
      await ProfileManager.instance.update(p.id);
      this.reload();
      promptAction.showToast({ message: '更新成功' });
    } catch (e) {
      promptAction.showToast({ message: `更新失败：${e instanceof Error ? e.message : String(e)}` });
    } finally {
      this.updating[p.id] = false;
      this.updating = Object.assign({}, this.updating) as Record<string, boolean>;
    }
  }

  private doSelect(p: Profile): void {
    try {
      ProfileManager.instance.select(p.id);
      this.currentId = p.id;
      this.appState.activeProfileName = p.name;
      if (this.appState.vpnRunning) {
        promptAction.showToast({ message: '已切换配置，重启连接后生效' });
      } else {
        promptAction.showToast({ message: `已启用：${p.name}` });
      }
    } catch (e) {
      promptAction.showToast({ message: `启用失败：${e instanceof Error ? e.message : String(e)}` });
    }
  }

  private doDelete(p: Profile): void {
    AlertDialog.show({
      title: '删除配置',
      message: `确定删除「${p.name}」吗？此操作不可恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: HColor.RED,
        action: () => {
          ProfileManager.instance.remove(p.id);
          this.reload();
          promptAction.showToast({ message: '已删除' });
        }
      }
    });
  }

  @Builder
  ProfileRow(p: Profile) {
    Column() {
      Row() {
        Text(p.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentId === p.id ? HColor.BRAND : HColor.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        if (this.currentId === p.id) {
          Text('✓ 当前')
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(HColor.BRAND);
        }
      }
      .width('100%');

      Text(`${p.url.length > 0 ? '订阅' : '本地'} · 更新 ${p.updatedAt > 0 ? formatDate(p.updatedAt / 1000) : '-'} · ${p.interval > 0 ? p.interval + ' 分钟自动' : '手动更新'}`)
        .fontSize(HDimens.FONT_CAPTION)
        .fontColor(HColor.TEXT_SECONDARY)
        .margin({ top: 4 });

      if (p.subInfo !== undefined && p.subInfo !== null && p.subInfo.total > 0) {
        Column() {
          Stack({ alignContent: Alignment.Start }) {
            Column()
              .width('100%')
              .height(4)
              .backgroundColor(HColor.DIVIDER)
              .borderRadius(2);
            Column()
              .width(`${percentOf(p.subInfo.upload + p.subInfo.download, p.subInfo.total)}%`)
              .height(4)
              .backgroundColor(HColor.GREEN)
              .borderRadius(2);
          }
          .width('100%')
          .margin({ top: 8 });

          Text(`已用 ${formatBytes(p.subInfo.upload + p.subInfo.download)} / ${formatBytes(p.subInfo.total)} · 到期 ${formatDate(p.subInfo.expire)}`)
            .fontSize(11)
            .fontColor(HColor.TEXT_TERTIARY)
            .margin({ top: 4 });
        }
        .width('100%');
      }

      Row({ space: 16 }) {
        if (this.currentId !== p.id) {
          Text('启用')
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(HColor.BRAND)
            .onClick(() => {
              this.doSelect(p);
            });
        }
        if (p.url.length > 0) {
          Text(this.updating[p.id] === true ? '更新中…' : '更新')
            .fontSize(HDimens.FONT_CAPTION)
            .fontColor(this.updating[p.id] === true ? HColor.TEXT_TERTIARY : HColor.BLUE)
            .onClick(() => {
              this.doUpdate(p);
            });
        }
        Text('编辑')
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.TEXT_SECONDARY)
          .onClick(() => {
            this.openEdit(p);
          });
        Text('删除')
          .fontSize(HDimens.FONT_CAPTION)
          .fontColor(HColor.RED)
          .onClick(() => {
            this.doDelete(p);
          });
      }
      .margin({ top: 10 });
    }
    .width('100%')
    .padding(HDimens.CARD_PADDING)
    .backgroundColor(HColor.CARD_BG)
    .borderRadius(HDimens.CARD_RADIUS)
    .border({ width: 1, color: this.currentId === p.id ? HColor.BRAND : HColor.CARD_BORDER });
  }

  private openEdit(p: Profile): void {
    const dialog: CustomDialogController = new CustomDialogController({
      builder: EditProfileDialog({
        profileName: p.name,
        profileInterval: p.interval,
        onConfirm: (name: string, interval: number) => {
          ProfileManager.instance.rename(p.id, name);
          ProfileManager.instance.setInterval(p.id, interval);
          this.reload();
          promptAction.showToast({ message: '已保存' });
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
    dialog.open();
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('订阅')
          .fontSize(HDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(HColor.TEXT_PRIMARY);
        Blank();
        Text('添加订阅')
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.BRAND)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(12)
          .margin({ right: 8 })
          .onClick(() => {
            this.addDialogController.open();
          });
        Text('本地导入')
          .fontSize(HDimens.FONT_BODY)
          .fontColor(HColor.BLUE)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(HColor.CARD_BG)
          .borderRadius(12)
          .onClick(() => {
            this.importDialogController.open();
          });
      }
      .width('100%')
      .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING, top: 12, bottom: 8 });

      if (this.profiles.length === 0) {
        EmptyState({
          title: '暂无订阅',
          desc: '添加订阅链接或导入本地配置开始使用',
          actionText: '添加订阅',
          onAction: () => {
            this.addDialogController.open();
          }
        });
      } else {
        List({ space: HDimens.CARD_GAP }) {
          ForEach(this.profiles, (p: Profile) => {
            ListItem() {
              this.ProfileRow(p);
            }
          }, (p: Profile) => `${p.id}-${this.currentId === p.id ? 'cur' : 'ncur'}-${p.name}`);
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: HDimens.PAGE_PADDING, right: HDimens.PAGE_PADDING })
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HColor.PAGE_BG);
  }
}
