//! 极简 SOCKS5 客户端（RFC 1928，无认证）。
//! 用途：TUN 中继把 TCP/UDP 流量注入本地 mixed 端口（127.0.0.1:mixed_port），
//! 从而进入 clash-rs 的规则/策略引擎。

use std::io;
use std::net::{Ipv4Addr, Ipv6Addr, SocketAddr};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpStream, UdpSocket};

const VER: u8 = 0x05;
const AUTH_NONE: u8 = 0x00;
const AUTH_NO_ACCEPTABLE: u8 = 0xFF;
const CMD_CONNECT: u8 = 0x01;
const CMD_UDP_ASSOCIATE: u8 = 0x03;
const REP_SUCCESS: u8 = 0x00;
const ATYP_V4: u8 = 0x01;
const ATYP_DOMAIN: u8 = 0x03;
const ATYP_V6: u8 = 0x04;

/// 将 SocketAddr 编码为 SOCKS5 地址（ATYP + ADDR + PORT）。
fn encode_addr(addr: SocketAddr, out: &mut Vec<u8>) {
    match addr {
        SocketAddr::V4(v4) => {
            out.push(ATYP_V4);
            out.extend_from_slice(&v4.ip().octets());
            out.extend_from_slice(&v4.port().to_be_bytes());
        }
        SocketAddr::V6(v6) => {
            out.push(ATYP_V6);
            out.extend_from_slice(&v6.ip().octets());
            out.extend_from_slice(&v6.port().to_be_bytes());
        }
    }
}

/// 解析 SOCKS5 地址，返回 (SocketAddr, 消费的字节数)。
fn decode_addr(buf: &[u8]) -> io::Result<(SocketAddr, usize)> {
    if buf.is_empty() {
        return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "addr empty"));
    }
    match buf[0] {
        ATYP_V4 => {
            if buf.len() < 1 + 4 + 2 {
                return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "v4 addr"));
            }
            let ip = Ipv4Addr::new(buf[1], buf[2], buf[3], buf[4]);
            let port = u16::from_be_bytes([buf[5], buf[6]]);
            Ok((SocketAddr::new(ip.into(), port), 7))
        }
        ATYP_V6 => {
            if buf.len() < 1 + 16 + 2 {
                return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "v6 addr"));
            }
            let mut octets = [0u8; 16];
            octets.copy_from_slice(&buf[1..17]);
            let port = u16::from_be_bytes([buf[17], buf[18]]);
            Ok((SocketAddr::new(Ipv6Addr::from(octets).into(), port), 19))
        }
        ATYP_DOMAIN => {
            if buf.len() < 2 {
                return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "domain addr"));
            }
            let len = buf[1] as usize;
            if buf.len() < 2 + len + 2 {
                return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "domain addr"));
            }
            let host = String::from_utf8_lossy(&buf[2..2 + len]).to_string();
            let port = u16::from_be_bytes([buf[2 + len], buf[3 + len]]);
            let addr: SocketAddr = format!("{host}:{port}")
                .parse()
                .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "bad domain addr"))?;
            Ok((addr, 4 + len))
        }
        _ => Err(io::Error::new(io::ErrorKind::InvalidData, "bad atyp")),
    }
}

async fn handshake(stream: &mut TcpStream, cmd: u8, target: SocketAddr) -> io::Result<SocketAddr> {
    // 方法协商：无认证
    stream.write_all(&[VER, 0x01, AUTH_NONE]).await?;
    let mut resp = [0u8; 2];
    stream.read_exact(&mut resp).await?;
    if resp[0] != VER || resp[1] == AUTH_NO_ACCEPTABLE {
        return Err(io::Error::new(io::ErrorKind::ConnectionRefused, "socks5 auth rejected"));
    }
    // 请求
    let mut req: Vec<u8> = vec![VER, cmd, 0x00];
    encode_addr(target, &mut req);
    stream.write_all(&req).await?;
    // 应答
    let mut head = [0u8; 4];
    stream.read_exact(&mut head).await?;
    if head[0] != VER {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "bad socks5 reply"));
    }
    if head[1] != REP_SUCCESS {
        return Err(io::Error::new(io::ErrorKind::ConnectionRefused, format!("socks5 rep {}", head[1])));
    }
    // 读取 BND.ADDR
    let mut addr_buf = vec![0u8; 1];
    // head[3] 是 ATYP，补齐剩余字节
    let rest_len = match head[3] {
        ATYP_V4 => 4 + 2,
        ATYP_V6 => 16 + 2,
        ATYP_DOMAIN => {
            stream.read_exact(&mut addr_buf).await?;
            addr_buf[0] as usize + 2
        }
        _ => return Err(io::Error::new(io::ErrorKind::InvalidData, "bad bnd atyp")),
    };
    let mut rest = vec![0u8; rest_len];
    stream.read_exact(&mut rest).await?;
    let mut full: Vec<u8> = Vec::with_capacity(1 + rest_len);
    full.push(head[3]);
    full.extend_from_slice(&rest);
    let (bound, _) = decode_addr(&full)?;
    Ok(bound)
}

/// 通过 SOCKS5 代理建立到 target 的 TCP 连接。
pub async fn connect(proxy: SocketAddr, target: SocketAddr) -> io::Result<TcpStream> {
    let mut stream = TcpStream::connect(proxy).await?;
    handshake(&mut stream, CMD_CONNECT, target).await?;
    Ok(stream)
}

/// SOCKS5 UDP ASSOCIATE 会话。
pub struct UdpAssociate {
    /// 控制连接（保持打开以维持关联；显式持有，不直接读取）
    #[allow(dead_code)]
    pub ctrl: TcpStream,
    /// 本地 UDP socket
    pub sock: UdpSocket,
    /// 服务器中继地址（发送封装后的数据报到此处）
    pub relay: SocketAddr,
}

/// 建立 UDP ASSOCIATE：proxy 为 SOCKS5 服务器地址。
pub async fn udp_associate(proxy: SocketAddr) -> io::Result<UdpAssociate> {
    let mut ctrl = TcpStream::connect(proxy).await?;
    // 本地 UDP socket（绑定任意端口）
    let sock = UdpSocket::bind("0.0.0.0:0").await?;
    let local = sock.local_addr()?;
    // 关联请求：DST 为本地 UDP 地址
    let relay = handshake(&mut ctrl, CMD_UDP_ASSOCIATE, local).await?;
    let relay = if relay.ip().is_unspecified() {
        SocketAddr::new(proxy.ip(), relay.port())
    } else {
        relay
    };
    Ok(UdpAssociate { ctrl, sock, relay })
}

/// 编码 UDP 请求/应答报文：RSV(2)=0, FRAG=0, ATYP/ADDR/PORT, payload。
pub fn encode_udp(dst: SocketAddr, payload: &[u8]) -> Vec<u8> {
    let mut out: Vec<u8> = Vec::with_capacity(10 + payload.len());
    out.extend_from_slice(&[0x00, 0x00, 0x00]);
    encode_addr(dst, &mut out);
    out.extend_from_slice(payload);
    out
}

/// 解码 UDP 应答报文，返回 (源地址, payload)。
pub fn decode_udp(buf: &[u8]) -> io::Result<(SocketAddr, &[u8])> {
    if buf.len() < 4 {
        return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "udp frame"));
    }
    if buf[2] != 0x00 {
        // 分片报文（FRAG != 0）：v1 直接丢弃
        return Err(io::Error::new(io::ErrorKind::Unsupported, "udp frag"));
    }
    let (addr, used) = decode_addr(&buf[3..])?;
    Ok((addr, &buf[3 + used..]))
}
