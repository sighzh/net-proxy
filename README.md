# Argosbx 优化版

> 洛杉矶节点延迟优化方案：BBR + TCP/UDP分流 + 进程监控

---

## 📁 目录结构

```
argosbx/
├── server/              # 服务端（VPS部署）
│   ├── install.sh       # 一键安装脚本
│   ├── network-optimize.sh  # BBR网络优化
│   └── watchdog.sh      # 进程监控
│
├── client/              # 客户端（本地部署）
│   ├── link-parser.sh   # 链接解析器（推荐）
│   ├── setup.sh         # 一键配置脚本
│   ├── docker-compose.yml
│   ├── config.json      # sing-box配置模板
│   └── USAGE.md         # 📖 使用说明
│
├── docs/                # 文档
│   ├── QUICK-START.md
│   └── ...
│
└── README.md
```

---

## 🚀 快速开始

### 服务端（VPS）

```bash
# 方式一：远程执行（推荐，无需下载）
bash <(curl -s https://raw.githubusercontent.com/sighzh/net-proxy/main/server/install.sh)

# 方式二：本地执行
git clone https://github.com/sighzh/net-proxy.git
cd net-proxy/server
hypt="" vlpt="" bbr="" watchdog="" bash install.sh

# 查看节点链接
px list
```

### 客户端（本地）

```bash
# 方式一：远程执行（推荐，无需下载）
bash <(curl -s https://raw.githubusercontent.com/sighzh/net-proxy/main/client/link-parser.sh)

# 方式二：本地执行
git clone https://github.com/sighzh/net-proxy.git
cd net-proxy/client
bash link-parser.sh

# 启动代理
cd ~/proxy && ./proxy.sh start
```

---

## 📋 基本信息

### 端口

| 端口 | 协议 | 地址 |
|------|------|------|
| 7890 | HTTP | `http://127.0.0.1:7890` |
| 7891 | SOCKS5 | `socks5://127.0.0.1:7891` |

### 网络模式

- **host 模式**：性能最佳，无端口映射

### 直连白名单

- 国内域名：`.cn`, `.中国` 等
- 国内网站：百度、淘宝、京东、QQ 等
- 私有IP：`192.168.x.x`, `10.x.x.x` 等

---

## 📖 详细文档

| 文档 | 说明 |
|------|------|
| [client/USAGE.md](client/USAGE.md) | **客户端使用说明** |
| [docs/QUICK-START.md](docs/QUICK-START.md) | 快速开始 |
| [docs/FNOS-GUIDE.md](docs/FNOS-GUIDE.md) | 飞牛OS指南 |

---

## 📊 分流规则

```
国内网站 → 直连（不走代理）
UDP流量 → Hysteria2（延迟最低）
TCP流量 → Vless-Reality（抗封锁）
```
