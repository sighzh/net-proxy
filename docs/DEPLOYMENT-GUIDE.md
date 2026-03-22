# px 优化版 - 最终部署指南

## 🎯 针对洛杉矶节点的完整解决方案

---

## 一、快速部署

### 1. 一键安装（推荐配置）

```bash
# Hysteria2 + Vless-Reality 双协议 + 全部优化
hypt="" vlpt="" bbr="" watchdog="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)
```

### 2. 本地部署

```bash
cd /home/z/my-project/net-proxy
hypt="" vlpt="" bbr="" watchdog="" bash server/install.sh
```

---

## 二、协议选择策略

### 🔥 推荐配置：双协议隔离

| 协议 | 传输层 | 用途 | 延迟 | 安全性 |
|------|--------|------|------|--------|
| **Hysteria2** | UDP/QUIC | 视频、游戏、实时通讯 | 最低 (+5-15ms) | 中等 |
| **Vless-Reality** | TCP | 网页浏览、下载、日常使用 | 中等 (+30-50ms) | 最高 |

### 📊 协议对比

```
┌─────────────────────────────────────────────────────────────┐
│                    协议特性对比                              │
├──────────────┬──────────┬──────────┬──────────┬────────────┤
│ 协议         │ 延迟     │ 带宽     │ 抗封锁   │ 推荐场景   │
├──────────────┼──────────┼──────────┼──────────┼────────────┤
│ Hysteria2    │ ⭐⭐⭐⭐⭐ │ ⭐⭐⭐⭐⭐ │ ⭐⭐⭐    │ 视频/游戏  │
│ Tuic         │ ⭐⭐⭐⭐  │ ⭐⭐⭐⭐  │ ⭐⭐⭐    │ 通用       │
│ Vless-Reality│ ⭐⭐⭐   │ ⭐⭐⭐   │ ⭐⭐⭐⭐⭐ │ 网页/下载  │
│ AnyTLS       │ ⭐⭐⭐   │ ⭐⭐⭐   │ ⭐⭐⭐⭐  │ 备用       │
└──────────────┴──────────┴──────────┴──────────┴────────────┘
```

---

## 三、防火墙应对策略

### 问题 1：Hysteria2 安全性

**现状分析**：
- Hysteria2 使用 TLS 1.3 加密，安全性足够
- 但 QUIC 协议特征明显，可能被识别

**解决方案**：

```bash
# 方案 A：启用 Salamander 混淆（推荐）
# 在服务端配置中添加：
"obfs": {
    "type": "salamander",
    "password": "your-obfs-password"
}

# 方案 B：使用非标准端口
hypt="随机高位端口" bash server/install.sh
```

### 问题 2：UDP 被封锁

**检测方法**：
```bash
./dual-protocol.sh test
```

**解决方案**：
```bash
# 纯 TCP 配置（抗封锁最强）
vlpt="" anpt="" bbr="" watchdog="" bash server/install.sh
```

### 问题 3：IP 被封锁

**解决方案**：
```bash
# Argo 隧道 + CDN
vmpt="" argo="vmpt" bbr="" watchdog="" bash server/install.sh
```

---

## 四、客户端分流配置

### 路由规则示例

```json
{
  "routing": {
    "rules": [
      {
        "outbound": "hysteria2-out",
        "protocol": "udp"
      },
      {
        "outbound": "hysteria2-out",
        "port": [443, 8443],
        "process": ["chrome", "firefox"]
      },
      {
        "outbound": "vless-reality-out",
        "network": "tcp"
      }
    ],
    "final": "vless-reality-out"
  }
}
```

### 分流策略

| 流量类型 | 推荐协议 | 原因 |
|----------|----------|------|
| UDP 流量 | Hysteria2 | 延迟最低 |
| 视频/直播 | Hysteria2 | 带宽最大 |
| 游戏 | Hysteria2 | 延迟敏感 |
| 网页浏览 | Vless-Reality | 抗封锁 |
| 文件下载 | Vless-Reality | 稳定性 |
| UDP 不通时 | Vless-Reality | 自动切换 |

---

## 五、完整配置示例

### 服务端配置

```bash
# 最推荐：双协议 + 全部优化
hypt="" vlpt="" bbr="" watchdog="" bash server/install.sh
```

### 客户端配置（v2rayN 示例）

```json
{
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 10808
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-out",
      "server": "your-server:port",
      "password": "your-uuid",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": ["h3"]
      },
      "obfs": {
        "type": "salamander",
        "password": "your-obfs-password"
      },
      "up_mbps": 50,
      "down_mbps": 100
    },
    {
      "type": "vless",
      "tag": "vless-out",
      "server": "your-server:port",
      "uuid": "your-uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "apple.com",
        "reality": {
          "enabled": true,
          "public_key": "your-public-key",
          "short_id": "your-short-id"
        }
      }
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "udp",
        "outbound": "hy2-out"
      }
    ],
    "final": "vless-out"
  }
}
```

---

## 六、运维命令

```bash
# 查看节点信息
px list

# 检查 BBR 状态
px bbr

# 检查防火墙环境
./dual-protocol.sh test

# 查看客户端分流建议
./dual-protocol.sh client

# 重启服务
px res

# 重置协议
hypt="" vlpt="" px rep
```

---

## 七、故障排查

### 问题 1：Hysteria2 连接失败

```bash
# 检查 UDP 是否通
./dual-protocol.sh test

# 如果 UDP 不通，切换到纯 TCP
vlpt="" bash server/install.sh
```

### 问题 2：延迟仍然很高

```bash
# 检查 BBR 是否启用
sysctl net.ipv4.tcp_congestion_control

# 如果不是 bbr，手动安装
px opt
```

### 问题 3：服务不稳定

```bash
# 检查进程监控
pgrep -f watchdog.sh

# 查看监控日志
cat ~/agsbx/watchdog.log
```

---

## 八、文件清单

```
px/
├── server/install.sh          # 优化版一键脚本
├── dual-protocol.sh        # 双协议配置助手
├── QUICK-START.md          # 快速启动指南
├── FIREWALL-ANALYSIS.md    # 防火墙分析
├── LATENCY-OPTIMIZATION.md # 延迟优化指南
├── OPTIMIZATION.md         # 稳定性优化说明
└── container/nodejs/
    ├── index.js            # 主服务（心跳、重连）
    ├── connection-pool.js  # 连接池管理
    ├── watchdog.sh         # 进程监控
    ├── server/network-optimize.sh # BBR+TCP/UDP优化
    └── hysteria2-optimize.sh
```

---

## 九、总结

### 洛杉矶节点最佳实践

```
┌─────────────────────────────────────────────────────────────┐
│                    推荐配置                                  │
├─────────────────────────────────────────────────────────────┤
│  协议: Hysteria2 + Vless-Reality 双协议                     │
│  优化: BBR + 进程监控 + 心跳保活                             │
│  分流: UDP → Hysteria2, TCP → Vless-Reality                 │
│  端口: Hysteria2 用高位端口, Vless-Reality 用 443           │
└─────────────────────────────────────────────────────────────┘
```

### 一键命令

```bash
hypt="" vlpt="" bbr="" watchdog="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)
```
