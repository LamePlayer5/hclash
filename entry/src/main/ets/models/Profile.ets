/**
 * 订阅（配置）档案模型。与 Clash Verge 的 profiles 概念对齐：
 * 每个 Profile 对应一个订阅 URL 或本地 YAML 文件，支持自动更新间隔与流量信息展示。
 */

export interface SubscriptionInfo {
  /** 已用上传流量（字节） */
  upload: number;
  /** 已用下载流量（字节） */
  download: number;
  /** 套餐总流量（字节），0 表示未知 */
  total: number;
  /** 套餐到期时间（Unix 秒），0 表示未知 */
  expire: number;
}

export interface Profile {
  /** 唯一 ID（时间戳+随机） */
  id: string;
  /** 显示名称 */
  name: string;
  /** 订阅 URL；本地导入时为空串 */
  url: string;
  /** 存储文件名（相对 profiles 目录，如 "abc.yaml"） */
  file: string;
  /** 创建时间（Unix 毫秒） */
  createdAt: number;
  /** 上次成功更新时间（Unix 毫秒），0 表示从未更新 */
  updatedAt: number;
  /** 自动更新间隔（分钟），0 = 不自动更新 */
  interval: number;
  /** 订阅流量信息（来自 subscription-userinfo 响应头） */
  subInfo?: SubscriptionInfo;
}

/** profiles/meta.json 的持久化结构 */
export interface ProfileStore {
  /** 当前选中的 profile id */
  current: string;
  profiles: Profile[];
}

/** 订阅下载时使用的 User-Agent（Clash Verge 默认伪装为 clash.meta） */
export const SUBSCRIPTION_UA: string = 'clash.meta/v1.18.0';

export function newProfileId(): string {
  const rand: number = Math.floor(Math.random() * 0xFFFFFF);
  return `p${Date.now().toString(36)}${rand.toString(36)}`;
}
