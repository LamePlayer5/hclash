import { vpnExtension } from '@kit.NetworkKit';
import { RuntimeConfig } from '../services/VpnService';

/** 自身包名（必须从 VPN 捕获中排除，否则内核出站流量会回流成环） */
const SELF_BUNDLE: string = 'com.hclash.app';

/**
 * 将 runtime.json 转换为系统的 VpnConfig。
 *
 * 说明（依据 @ohos.net.vpnExtension 官方文档核验）：
 * - MTU 系统限制 [576, 1500]
 * - 隧道地址使用 10.0.0.2/24（仅作为 TUN 接口本端地址）
 * - routes 0.0.0.0/0（+ ::/0）全量接管
 * - **自环防护**：trustedApplications 与 blockedApplications 不能同时配置；
 *   非白名单模式时必须把自身包名加入 blockedApplications，确保 clash 内核
 *   的出站流量直接走物理网络（等价于 Android VpnService.protect()）
 */
export function buildVpnConfig(runtime: RuntimeConfig): vpnExtension.VpnConfig {
  const addresses: vpnExtension.LinkAddress[] = [
    {
      address: { address: '10.0.0.2', family: 1 },
      prefixLength: 24
    }
  ];
  if (runtime.ipv6) {
    addresses.push({
      address: { address: 'fdfe:dcba:9876::2', family: 2 },
      prefixLength: 126
    });
  }

  const routes: vpnExtension.RouteInfo[] = [
    {
      interface: '',
      destination: {
        address: { address: '0.0.0.0', family: 1 },
        prefixLength: 0
      },
      gateway: { address: '10.0.0.1', family: 1 },
      hasGateway: false,
      isDefaultRoute: true
    }
  ];
  if (runtime.ipv6) {
    routes.push({
      interface: '',
      destination: {
        address: { address: '::', family: 2 },
        prefixLength: 0
      },
      gateway: { address: 'fdfe:dcba:9876::1', family: 2 },
      hasGateway: false,
      isDefaultRoute: true
    });
  }

  // MTU 钳制到系统允许范围 [576, 1500]
  let mtu: number = runtime.mtu;
  if (isNaN(mtu) || mtu < 576) {
    mtu = 576;
  } else if (mtu > 1500) {
    mtu = 1500;
  }

  const config: vpnExtension.VpnConfig = {
    addresses: addresses,
    routes: routes,
    dnsAddresses: runtime.dnsServers,
    mtu: mtu,
    isIPv4Accepted: true,
    isIPv6Accepted: runtime.ipv6,
    isInternal: false,
    isBlocking: false
  };

  // 分应用代理 + 自环防护（两类列表互斥）
  if (runtime.perAppMode === 'allow' && runtime.perAppPackages.length > 0) {
    // 白名单：仅选中应用走 VPN；自身不在列表 → 出站不被捕获，安全
    config.trustedApplications = runtime.perAppPackages;
  } else {
    // 黑名单（或未启用分应用）：始终排除自身包名
    const blocked: string[] = runtime.perAppMode === 'block'
      ? runtime.perAppPackages.slice() as string[]
      : [];
    if (blocked.indexOf(SELF_BUNDLE) < 0) {
      blocked.push(SELF_BUNDLE);
    }
    config.blockedApplications = blocked;
  }

  return config;
}
