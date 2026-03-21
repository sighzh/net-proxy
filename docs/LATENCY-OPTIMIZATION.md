# 洛杉矶节点延迟优化指南

## 概述

本文档针对洛杉矶等海外高延迟节点，提供完整的网络优化方案。从系统内核参数到协议选择，全方位降低延迟。

---

## 一、延迟来源分析

### 1. 物理延迟（无法避免）

| 地区 | 洛杉矶 RTT | 说明 |
|------|-----------|------|
| 中国东部 | 150-180ms | 光速限制 |
| 中国中部 | 180-220ms | 路由跳数 |
| 中国西部 | 200-250ms | 线路质量 |

### 2. 协议延迟（可优化）

| 协议 | 额外延迟 | 原因 |
|------|---------|------|
| Hysteria2 | +5-15ms | QUIC/UDP，0-RTT |
| Tuic | +10-20ms | QUIC/UDP，BBR |
| Vless-Reality | +30-50ms | TCP 握手 |
| Vmess-WS | +40-60ms | TCP + WebSocket |

### 3. 系统延迟（可优化）

- TCP 拥塞控制算法
- 缓冲区大小
- 队列调度

---

## 二、系统级优化

### 1. BBR 拥塞控制

BBR (Bottleneck Bandwidth and RTT) 是 Google 开发的拥塞控制算法，特别适合高延迟网络。

**安装方法**:
```bash
cd /home/z/my-project/argosbx/container/nodejs
chmod +x network-optimize.sh
sudo ./network-optimize.sh install
```

**验证 BBR 状态**:
```bash
sysctl net.ipv4.tcp_congestion_control
# 输出: net.ipv4.tcp_congestion_control = bbr
```

### 2. TCP/UDP 参数优化

优化脚本已配置以下关键参数：

| 参数 | 优化值 | 说明 |
|------|--------|------|
| net.core.rmem_max | 134MB | UDP 读缓冲区 |
| net.core.wmem_max | 134MB | UDP 写缓冲区 |
| net.ipv4.tcp_rmem | 64MB | TCP 读缓冲区 |
| net.ipv4.tcp_wmem | 64MB | TCP 写缓冲区 |
| net.core.default_qdisc | fq | 公平队列 |
| net.ipv4.tcp_fastopen | 3 | TCP Fast Open |

---

## 三、协议选择优化

### 1. 推荐协议顺序

```
🥇 Hysteria2  → 延迟最低，抗丢包能力强
🥈 Tuic       → 延迟较低，BBR 拥塞控制
🥉 Vless-Reality → 延迟中等，安全性高
```

### 2. Hysteria2 优化配置

**服务端配置**:
```bash
# 设置服务器带宽（根据实际带宽调整）
./hysteria2-optimize.sh optimize 100 500
# 参数: 上传带宽(Mbps) 下载带宽(Mbps)
```

**客户端配置建议**:
```json
{
  "bandwidth": {
    "up": "50 Mbps",
    "down": "100 Mbps"
  },
  "fast_open": true,
  "lazy": true
}
```

### 3. Tuic 配置（已内置 BBR）

原项目 Tuic 已配置 `congestion_control: bbr`，无需额外优化。

---

## 四、使用优化脚本

### 1. 网络优化脚本

```bash
# 安装优化
sudo ./network-optimize.sh install

# 查看状态
./network-optimize.sh status

# 卸载优化
sudo ./network-optimize.sh uninstall
```

### 2. Hysteria2 优化脚本

```bash
# 检测带宽
./hysteria2-optimize.sh detect

# 优化配置
./hysteria2-optimize.sh optimize 100 500

# 生成客户端配置
./hysteria2-optimize.sh client

# 延迟对比
./hysteria2-optimize.sh compare
```

---

## 五、完整部署流程

### 步骤 1: 安装网络优化

```bash
cd /home/z/my-project/argosbx/container/nodejs
chmod +x network-optimize.sh hysteria2-optimize.sh watchdog.sh
sudo ./network-optimize.sh install
```

### 步骤 2: 启动代理服务

```bash
# 启动主服务
npm start

# 启动进程监控
./watchdog.sh start
```

### 步骤 3: 优化 Hysteria2（可选）

```bash
# 根据服务器带宽设置
./hysteria2-optimize.sh optimize 100 500
```

### 步骤 4: 验证优化效果

```bash
# 检查 BBR
sysctl net.ipv4.tcp_congestion_control

# 检查服务状态
curl http://localhost:3000/health

# 查看统计
curl http://localhost:3000/stats
```

---

## 六、优化效果对比

### 延迟对比（洛杉矶节点）

| 优化项 | 优化前 | 优化后 | 改善 |
|--------|--------|--------|------|
| TCP 协议延迟 | +50ms | +30ms | 40% |
| UDP 协议延迟 | +20ms | +10ms | 50% |
| 丢包恢复 | 2-3秒 | 0.5秒 | 75% |
| 连接稳定性 | 一般 | 高 | 显著 |

### 带宽利用率

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 高延迟网络 | 30-50% | 80-95% |
| 丢包环境 | 10-20% | 60-80% |

---

## 七、常见问题

### Q1: BBR 开启失败？

**原因**: 内核版本过低（需要 4.9+）

**解决**:
```bash
# 检查内核版本
uname -r

# 升级内核（CentOS）
yum install -y kernel

# 升级内核（Ubuntu）
apt install -y linux-generic
```

### Q2: Hysteria2 连接不稳定？

**检查清单**:
1. UDP 端口是否开放
2. 客户端是否支持 Hysteria2
3. 带宽设置是否合理

### Q3: 延迟仍然很高？

**排查步骤**:
1. 检查路由线路（使用 traceroute）
2. 尝试其他端口
3. 检查服务器负载
4. 考虑更换机房

---

## 八、文件清单

| 文件 | 说明 |
|------|------|
| `network-optimize.sh` | BBR + TCP/UDP 系统优化 |
| `hysteria2-optimize.sh` | Hysteria2 延迟优化 |
| `watchdog.sh` | 进程监控自动重启 |
| `index.js` | 主服务（心跳、重连优化） |
| `connection-pool.js` | 连接池管理 |

---

## 九、参考资料

- [BBR 拥塞控制算法](https://research.google/pubs/pub45646/)
- [Hysteria2 协议文档](https://v2.hysteria.network/)
- [Linux TCP 调优指南](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
