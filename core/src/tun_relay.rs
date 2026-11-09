//! TUN 中继（tun2socks 风格）：
//! 系统 VPN 隧道 fd（HarmonyOS vpnExtension 提供）→ watfaq-netstack 用户态协议栈
//! → SOCKS5 出站 → 本地 mixed 端口 → clash-rs 规则/策略引擎。
//!
//! 数据路径：
//!   [设备应用] → TUN fd → NetStack (smoltcp) ──┬─ TCP: TcpListener.accept → SOCKS5 CONNECT
//!                                              └─ UDP: UdpSocket → SOCKS5 UDP ASSOCIATE
//!   TUN fd ← NetStack ←──────────────────────── 回程报文
//!
//! 该方案与 clash-rs 官方 iOS 客户端（ChocLite）同构：watfaq-netstack 即其用户态栈组件。

use watfaq_netstack::{NetStack, Packet, UdpPacket};
use futures::{SinkExt, StreamExt};
use std::collections::HashMap;
use std::io;
use std::net::SocketAddr;
use std::os::unix::io::RawFd;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::unix::AsyncFd;
use tokio::sync::{mpsc, oneshot};

const MTU: usize = 65535;
const MAX_UDP_FLOWS: usize = 8192;

/// TUN fd 封装：拥有 fd 并在 drop 时关闭。
struct TunFd {
    raw: RawFd,
}

impl std::os::unix::io::AsRawFd for TunFd {
    fn as_raw_fd(&self) -> RawFd {
        self.raw
    }
}

impl Drop for TunFd {
    fn drop(&mut self) {
        unsafe {
            libc::close(self.raw);
        }
    }
}

fn set_nonblocking(fd: RawFd) -> io::Result<()> {
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 {
        return Err(io::Error::last_os_error());
    }
    if unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// 中继句柄：`stop()` 等待中继线程退出并释放 fd。
pub struct RelayHandle {
    stop_tx: Option<oneshot::Sender<()>>,
    join: Option<std::thread::JoinHandle<()>>,
}

impl RelayHandle {
    /// 在独立线程 + 独立 tokio runtime 中启动中继。
    pub fn spawn(tun_fd: i32, mixed_port: u16) -> io::Result<Self> {
        let (stop_tx, stop_rx) = oneshot::channel::<()>();
        let join = std::thread::Builder::new()
            .name("hclash-tun-relay".to_string())
            .spawn(move || {
                let rt = match tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(2)
                    .enable_all()
                    .build()
                {
                    Ok(rt) => rt,
                    Err(e) => {
                        log::error!("[tun-relay] runtime build failed: {e}");
                        return;
                    }
                };
                rt.block_on(relay_main(tun_fd, mixed_port, stop_rx));
                rt.shutdown_timeout(Duration::from_secs(2));
            })?;
        Ok(Self {
            stop_tx: Some(stop_tx),
            join: Some(join),
        })
    }

    /// 停止中继并等待线程退出。
    pub fn stop(mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
        if let Some(h) = self.join.take() {
            let _ = h.join();
        }
    }
}

/// 中继主循环。
async fn relay_main(tun_fd: i32, mixed_port: u16, stop_rx: oneshot::Receiver<()>) {
    if let Err(e) = set_nonblocking(tun_fd) {
        log::error!("[tun-relay] set nonblocking failed: {e}");
        return;
    }
    let proxy: SocketAddr = SocketAddr::from(([127, 0, 0, 1], mixed_port));
    let tun = Arc::new(AsyncFd::new(TunFd { raw: tun_fd }).expect("AsyncFd"));
    let (stack, listener, net_udp) = NetStack::new();
    let (mut sink, mut stream) = stack.split();

    // 1) TUN fd → 协议栈
    {
        let tun = Arc::clone(&tun);
        tokio::spawn(async move {
            loop {
                let mut guard = match tun.readable().await {
                    Ok(g) => g,
                    Err(_) => return,
                };
                let pkt = match guard.try_io(|inner| {
                    let mut buf = vec![0u8; MTU];
                    let n = unsafe {
                        libc::read(
                            inner.get_ref().raw,
                            buf.as_mut_ptr() as *mut libc::c_void,
                            buf.len(),
                        )
                    };
                    if n < 0 {
                        Err(io::Error::last_os_error())
                    } else {
                        buf.truncate(n as usize);
                        Ok(buf)
                    }
                }) {
                    Ok(Ok(p)) => p,
                    Ok(Err(e)) => {
                        log::warn!("[tun-relay] tun read error: {e}");
                        return;
                    }
                    Err(_) => continue, // WouldBlock：重新等待可读
                };
                if pkt.is_empty() {
                    continue;
                }
                if sink.send(Packet::new(pkt)).await.is_err() {
                    return;
                }
            }
        });
    }

    // 2) 协议栈 → TUN fd
    {
        let tun = Arc::clone(&tun);
        tokio::spawn(async move {
            while let Some(item) = stream.next().await {
                let pkt = match item {
                    Ok(p) => p,
                    Err(e) => {
                        log::warn!("[tun-relay] stack stream error: {e}");
                        continue;
                    }
                };
                let data = pkt.into_bytes();
                let mut off = 0usize;
                while off < data.len() {
                    let mut guard = match tun.writable().await {
                        Ok(g) => g,
                        Err(_) => return,
                    };
                    let slice = &data[off..];
                    let r = guard.try_io(|inner| {
                        let n = unsafe {
                            libc::write(
                                inner.get_ref().raw,
                                slice.as_ptr() as *const libc::c_void,
                                slice.len(),
                            )
                        };
                        if n < 0 {
                            Err(io::Error::last_os_error())
                        } else {
                            Ok(n as usize)
                        }
                    });
                    match r {
                        Ok(Ok(n)) => off += n,
                        Ok(Err(e)) => {
                            log::warn!("[tun-relay] tun write error: {e}");
                            return;
                        }
                        Err(_) => continue, // WouldBlock：重新等待可写
                    }
                }
            }
        });
    }

    // 3) TCP：接受用户态栈中的入站 TCP 流，经 SOCKS5 CONNECT 注入 mixed 端口
    {
        let mut listener = listener;
        tokio::spawn(async move {
            while let Some(mut stream) = listener.next().await {
                let remote = stream.remote_addr();
                let proxy = proxy;
                tokio::spawn(async move {
                    match crate::socks5::connect(proxy, remote).await {
                        Ok(mut up) => {
                            let _ = tokio::io::copy_bidirectional(&mut stream, &mut up).await;
                        }
                        Err(e) => {
                            log::debug!("[tun-relay] tcp dial failed {remote}: {e}");
                        }
                    }
                    // stream drop → 协议栈发起 FIN
                });
            }
        });
    }

    // 4) UDP：经 SOCKS5 UDP ASSOCIATE 转发
    {
        let (mut udp_read, mut udp_write) = net_udp.split();
        let assoc = match crate::socks5::udp_associate(proxy).await {
            Ok(a) => Arc::new(a),
            Err(e) => {
                log::warn!("[tun-relay] udp associate failed: {e}（UDP 流量将不可用）");
                let _ = stop_rx.await;
                return;
            }
        };

        // 回程：SOCKS5 中继 → 设备
        let (reply_tx, mut reply_rx) = mpsc::unbounded_channel::<(SocketAddr, Vec<u8>)>();
        {
            let assoc = Arc::clone(&assoc);
            tokio::spawn(async move {
                let mut buf = vec![0u8; MTU];
                loop {
                    match assoc.sock.recv(&mut buf).await {
                        Ok(n) => {
                            if let Ok((src, payload)) = crate::socks5::decode_udp(&buf[..n]) {
                                let _ = reply_tx.send((src, payload.to_vec()));
                            }
                        }
                        Err(_) => return, // ctrl 连接关闭时 sock 随之失效
                    }
                }
                // _assoc 保持存活直到循环退出
                #[allow(unreachable_code)]
                {
                    drop(assoc);
                }
            });
        }

        // 设备 → SOCKS5 中继，同时维护 (远端 → 设备源) 映射
        let mut flow_map: HashMap<SocketAddr, SocketAddr> = HashMap::new();
        loop {
            tokio::select! {
                maybe = udp_read.recv() => {
                    match maybe {
                        Some(pkt) => {
                            if flow_map.len() >= MAX_UDP_FLOWS {
                                flow_map.clear();
                            }
                            flow_map.insert(pkt.remote_addr, pkt.local_addr);
                            let frame = crate::socks5::encode_udp(pkt.remote_addr, pkt.data());
                            if assoc.sock.send_to(&frame, assoc.relay).await.is_err() {
                                log::debug!("[tun-relay] udp send failed");
                            }
                        }
                        None => break,
                    }
                }
                maybe_reply = reply_rx.recv() => {
                    match maybe_reply {
                        Some((src, payload)) => {
                            if let Some(dev_local) = flow_map.get(&src) {
                                let out = UdpPacket::from((payload, src, *dev_local));
                                let _ = udp_write.send(out).await;
                            }
                        }
                        None => break,
                    }
                }
            }
        }
    }

    // 等待停止信号（任务在 runtime 关闭时统一回收）
    let _ = stop_rx.await;
}
