import { vpnExtension } from '@kit.NetworkKit';
import { RuntimeConfig } from '../services/VpnService';

/**
 * 将 runtime.json 转换为系统的 VpnConfig。
 *
 * 说明：
 * - 隧道地址使用 10.0.0.2/24（仅作为 TUN 接口本端地址，与真实内网网段冲突概率低）
 * - routes 0.0.0.0/0（+ ::/0）全量接管，分应用代理通过 trusted/blocked 列表实现
 * - bypassPrivate 预留：若系统支持路由排除，可在此追加私网 bypass 规则
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

  const config: vpnExtension.VpnConfig = {
    addresses: addresses,
    routes: routes,
    dnsAddresses: runtime.dnsServers,
    mtu: runtime.mtu,
    isIPv4Accepted: true,
    isIPv6Accepted: runtime.ipv6,
    isInternal: false,
    isBlocking: false
  };

  // 分应用代理：白名单 → trustedApplications；黑名单 → blockedApplications
  if (runtime.perAppMode === 'allow' && runtime.perAppPackages.length > 0) {
    config.trustedApplications = runtime.perAppPackages;
  } else if (runtime.perAppMode === 'block' && runtime.perAppPackages.length > 0) {
    config.blockedApplications = runtime.perAppPackages;
  }

  return config;
}
