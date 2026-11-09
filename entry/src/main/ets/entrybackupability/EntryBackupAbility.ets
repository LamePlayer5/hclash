import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { Log } from '../utils/Logger';

const TAG: string = 'EntryBackupAbility';

/**
 * 数据备份扩展（系统接入备份恢复框架所需）。
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    Log.i(TAG, 'onBackup');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    Log.i(TAG, `onRestore: ${bundleVersion.code} ${bundleVersion.name}`);
  }
}
