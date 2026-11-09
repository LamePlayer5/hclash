/**
 * 应用设置模型。持久化在 preferences（hclash_settings）。
 */

/** 分应用代理模式 */
export enum PerAppMode {
  Off = 'off',
  /** 白名单：仅选中应用走代理（VPN 仅捕获这些应用） */
  AllowList = 'allow',
  /** 黑名单：选中应用绕过代理 */
  BlockList = 'block'
}

export interface PerAppProxy {
  mode: PerAppMode;
  packages: string[];
}

export interface AppSettings {
  /** 主题：system / light / dark（当前版本默认 dark） */
  themeMode: string;
  /** 语言：system / zh / en */
  language: string;
  /** 内核日志级别：silent/error/warning/info/debug */
  logLevel: string;
  /** 外部控制器端口 */
  apiPort: number;
  /** 外部控制器密钥（本机回环，默认空） */
  apiSecret: string;
  /** 代理模式 */
  mode: string;
  /** TUN MTU（系统限制 576–1500） */
  tunMtu: number;
  /** 自定义 DNS（VPN 隧道的 DNS 列表） */
  dnsServers: string[];
  /** IPv6 路由开关 */
  ipv6: boolean;
  /** 允许局域网连接（allow-lan） */
  allowLan: boolean;
  /** mixed 端口 */
  mixedPort: number;
  /** 系统启动后自动连接（配合系统始终开启 VPN） */
  autoConnect: boolean;
  /** 应用启动时自动连接上次配置 */
  connectOnLaunch: boolean;
  /** 绕过中国大陆常用网段（在 VPN routes 中排除私网/保留地址） */
  bypassPrivateNetworks: boolean;
  /** 分应用代理 */
  perApp: PerAppProxy;
  /** 延迟测试 URL */
  delayTestUrl: string;
}

export function defaultSettings(): AppSettings {
  return {
    themeMode: 'dark',
    language: 'system',
    logLevel: 'info',
    apiPort: 9090,
    apiSecret: '',
    mode: 'rule',
    tunMtu: 1500,
    dnsServers: ['223.5.5.5', '119.29.29.29'],
    ipv6: false,
    allowLan: false,
    mixedPort: 7890,
    autoConnect: false,
    connectOnLaunch: false,
    bypassPrivateNetworks: true,
    perApp: {
      mode: PerAppMode.Off,
      packages: []
    },
    delayTestUrl: 'https://www.gstatic.com/generate_204'
  };
}
