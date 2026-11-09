/**
 * 格式化工具：字节、速率、时长、时间。
 */

const KB: number = 1024;
const MB: number = KB * 1024;
const GB: number = MB * 1024;
const TB: number = GB * 1024;

/** 字节数 → 人类可读，如 1.5 GB */
export function formatBytes(bytes: number): string {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < KB) {
    return `${bytes} B`;
  }
  if (bytes < MB) {
    return `${(bytes / KB).toFixed(1)} KB`;
  }
  if (bytes < GB) {
    return `${(bytes / MB).toFixed(1)} MB`;
  }
  if (bytes < TB) {
    return `${(bytes / GB).toFixed(2)} GB`;
  }
  return `${(bytes / TB).toFixed(2)} TB`;
}

/** 每秒字节数 → 速率文本，如 1.2 MB/s */
export function formatSpeed(bps: number): string {
  return `${formatBytes(bps)}/s`;
}

/** Unix 秒 → 日期文本 yyyy/MM/dd */
export function formatDate(unixSec: number): string {
  if (unixSec <= 0) {
    return '-';
  }
  const d: Date = new Date(unixSec * 1000);
  return `${d.getFullYear()}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')}`;
}

/** ISO 时间串 → HH:mm:ss */
export function formatTime(iso: string): string {
  try {
    const d: Date = new Date(iso);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}:${d.getSeconds().toString().padStart(2, '0')}`;
  } catch (e) {
    return iso;
  }
}

/** 毫秒 → 时长文本，如 3天2小时 */
export function formatDuration(ms: number): string {
  if (ms < 0) {
    ms = 0;
  }
  const sec: number = Math.floor(ms / 1000);
  const days: number = Math.floor(sec / 86400);
  const hours: number = Math.floor((sec % 86400) / 3600);
  const mins: number = Math.floor((sec % 3600) / 60);
  if (days > 0) {
    return `${days}天${hours}小时`;
  }
  if (hours > 0) {
    return `${hours}小时${mins}分`;
  }
  if (mins > 0) {
    return `${mins}分${sec % 60}秒`;
  }
  return `${sec}秒`;
}

/** 延迟显示：<=0 显示超时，其余显示毫秒 */
export function formatDelay(delay: number): string {
  if (delay <= 0) {
    return '超时';
  }
  return `${delay}ms`;
}

/** 百分比（0-100），无 total 时返回 -1 */
export function percentOf(used: number, total: number): number {
  if (total <= 0) {
    return -1;
  }
  const p: number = (used / total) * 100;
  return p > 100 ? 100 : p;
}
