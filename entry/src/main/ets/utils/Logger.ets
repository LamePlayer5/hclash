import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 统一日志封装（hilog）。
 * 域 0x0201 为应用自定义域。
 */
const DOMAIN: number = 0x0201;
const TAG: string = 'HClash';

export class Log {
  static d(subTag: string, msg: string): void {
    hilog.debug(DOMAIN, TAG, `[${subTag}] ${msg}`);
  }

  static i(subTag: string, msg: string): void {
    hilog.info(DOMAIN, TAG, `[${subTag}] ${msg}`);
  }

  static w(subTag: string, msg: string): void {
    hilog.warn(DOMAIN, TAG, `[${subTag}] ${msg}`);
  }

  static e(subTag: string, msg: string): void {
    hilog.error(DOMAIN, TAG, `[${subTag}] ${msg}`);
  }

  /** 提取异常的字符串描述 */
  static err(e: Object): string {
    if (e instanceof Error) {
      return `${e.name}: ${e.message}`;
    }
    return JSON.stringify(e);
  }
}
