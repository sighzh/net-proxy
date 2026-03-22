# px 优化版 - 快速启动指南

## 🚀 命令说明

命令已简化为 `px`（proxy 缩写），简单好记！

---

## 一、一键启动命令

### 基础用法

```bash
# Hysteria2 协议（推荐，延迟最低）
hypt="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)

# Tuic 协议
tupt="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)

# Vless-TCP-Reality 协议
vlpt="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)
```

### 优化版用法（推荐）

```bash
# Hysteria2 + BBR优化 + 进程监控（推荐）
hypt="" bbr="" watchdog="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)

# 多协议组合 + 全部优化
hypt="" tupt="" vlpt="" bbr="" watchdog="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)
```

---

## 二、快捷命令

安装后可用 `px` 命令：

```bash
px list    # 显示节点信息
px rep     # 重置协议配置
px res     # 重启服务
px bbr     # 检查BBR状态
px opt     # 安装网络优化
px del     # 卸载
```

---

## 三、变量说明

### 协议变量（必选其一）

| 变量 | 协议 | 内核 | 延迟 | 推荐 |
|------|------|------|------|------|
| `hypt=""` | Hysteria2 | UDP/QUIC | 最低 | ⭐⭐⭐ |
| `tupt=""` | Tuic | UDP/QUIC | 低 | ⭐⭐ |
| `vlpt=""` | Vless-TCP-Reality | TCP | 中 | ⭐ |
| `vmpt=""` | Vmess-WS | TCP | 中 | ⭐ |

### 优化变量（可选）

| 变量 | 功能 | 说明 |
|------|------|------|
| `bbr=""` | BBR网络优化 | 高延迟网络必备 |
| `watchdog=""` | 进程监控 | 自动重启崩溃服务 |

---

## 四、洛杉矶节点推荐配置

```bash
# 最佳配置：Hysteria2 + BBR + 进程监控
hypt="" bbr="" watchdog="" bash <(curl -Ls https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)
```

**预期效果**：
- 延迟降低 40-50%
- 带宽利用率提升 2-3 倍
- 服务稳定性显著提升

---

## 五、完整示例

```bash
# 1. 安装
hypt="" vlpt="" bbr="" watchdog="" bash <(curl -Ls https://your-server/server/install.sh)

# 2. 查看节点
px list

# 3. 检查BBR
px bbr

# 4. 重启服务
px res
```
