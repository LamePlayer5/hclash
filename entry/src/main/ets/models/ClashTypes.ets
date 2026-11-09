/**
 * Clash External Controller RESTful API 的数据模型。
 * 与 mihomo / clash-rs 的 /proxies /rules /connections 等接口返回结构对齐。
 */

export interface DelayHistory {
  time: string;
  delay: number;
}

/**
 * 代理节点或代理组。
 * 当 all 非空时表示这是一个代理组（Selector/URLTest/Fallback/LoadBalance）。
 */
export interface ProxyInfo {
  name: string;
  type: string;
  now?: string;
  all?: string[];
  udp?: boolean;
  xudp?: boolean;
  tfo?: boolean;
  alive?: boolean;
  history?: DelayHistory[];
  icon?: string;
  fixed?: string;
  expectedStatus?: string;
}

export interface ProxiesResp {
  proxies: Record<string, ProxyInfo>;
}

export interface DelayResp {
  delay: number;
  message?: string;
  meanDelay?: number;
}

export interface RuleInfo {
  type: string;
  payload: string;
  proxy: string;
  size?: number;
}

export interface RulesResp {
  rules: RuleInfo[];
}

export interface ConnectionMetadata {
  network: string;
  type: string;
  sourceIP: string;
  destinationIP: string;
  sourcePort: string;
  destinationPort: string;
  host: string;
  dnsMode: string;
  process?: string;
  processPath?: string;
  uid?: number;
  sniffHost?: string;
  specialProxy?: string;
  destinationGeoIP?: string[];
}

export interface ConnectionInfo {
  id: string;
  metadata: ConnectionMetadata;
  upload: number;
  download: number;
  start: string;
  chains: string[];
  rule: string;
  rulePayload: string;
}

export interface ConnectionsResp {
  downloadTotal: number;
  uploadTotal: number;
  memory?: number;
  connections: ConnectionInfo[];
}

export interface TrafficFrame {
  up: number;
  down: number;
}

export interface LogEntry {
  type: string;
  payload: string;
}

export interface VersionInfo {
  version: string;
  premium?: boolean;
  meta?: boolean;
}

/** /configs 返回的运行时配置（字段与 mihomo 对齐，按需取用） */
export interface GeneralConfig {
  port?: number;
  'socks-port'?: number;
  'redir-port'?: number;
  'tproxy-port'?: number;
  'mixed-port'?: number;
  authentication?: string[];
  'allow-lan'?: boolean;
  'bind-address'?: string;
  mode?: string;
  'log-level'?: string;
  ipv6?: boolean;
  'external-controller'?: string;
  'external-ui'?: string;
  secret?: string;
  'unified-delay'?: boolean;
  'tcp-concurrent'?: boolean;
  'interface-name'?: string;
  tun?: TunConfig;
}

export interface TunConfig {
  enable?: boolean;
  stack?: string;
  device?: string;
  'dns-hijack'?: string[];
  'auto-route'?: boolean;
  'auto-detect-interface'?: boolean;
  mtu?: number;
}

/** 代理模式 */
export enum ProxyMode {
  Rule = 'rule',
  Global = 'global',
  Direct = 'direct'
}

/** 延迟测试地址（Clash 惯例） */
export const DEFAULT_DELAY_URL: string = 'https://www.gstatic.com/generate_204';
export const DEFAULT_DELAY_TIMEOUT: number = 5000;
