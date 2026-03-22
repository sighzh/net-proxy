# 飞牛OS / Docker 一键代理使用指南

## 🚀 最简单的方式：粘贴链接即可

### 步骤 1：获取节点链接

在服务器上运行：
```bash
px list
```

复制输出的链接，例如：
```
hysteria2://uuid@server:port?security=tls&alpn=h3&sni=www.bing.com#节点名称
vless://uuid@server:port?security=reality&sni=apple.com&pbk=xxx&sid=xxx#节点名称
```

### 步骤 2：运行链接解析脚本

```bash
# 解压
unzip px-optimized.zip
cd px

# 运行解析脚本
bash client/link-parser.sh
```

### 步骤 3：粘贴链接

```
==========================================
  代理链接解析器
  支持直接粘贴节点链接
==========================================

请粘贴节点链接（支持多个链接，一行一个，空行结束）：

hysteria2://79411d85-b0dc-4cd2-b46c-01789a18c650@123.45.67.89:443?security=tls&alpn=h3&sni=www.bing.com#LA-hy2
vless://79411d85-b0dc-4cd2-b46c-01789a18c650@123.45.67.89:443?security=reality&sni=apple.com&pbk=abc123&sid=0123456789abcdef#LA-vless

（按回车结束）
```

### 步骤 4：自动生成配置并启动

脚本会自动：
1. ✅ 解析链接参数
2. ✅ 生成 sing-box 配置
3. ✅ 生成 client/docker-compose.yml
4. ✅ 生成控制脚本
5. ✅ 询问是否立即启动

---

## 📋 支持的协议链接

| 协议 | 链接格式 | 说明 |
|------|----------|------|
| Hysteria2 | `hysteria2://...` | UDP协议，延迟最低 |
| Vless-Reality | `vless://...` | TCP协议，抗封锁 |
| Vmess | `vmess://...` | 通用协议 |
| Tuic | `tuic://...` | UDP协议 |

---

## 🔧 控制命令

```bash
cd ~/proxy

# 启动
./proxy.sh start

# 停止
./proxy.sh stop

# 重启
./proxy.sh restart

# 查看状态
./proxy.sh status

# 查看日志
./proxy.sh logs

# 测试连接
./proxy.sh test
```

---

## 🌐 使用代理

### 方法一：环境变量

```bash
# 开启
source ~/proxy/env.sh on

# 关闭
source ~/proxy/env.sh off
```

### 方法二：命令行指定

```bash
# HTTP代理
curl -x http://127.0.0.1:7890 https://ip.sb

# SOCKS代理
curl -x socks5://127.0.0.1:7891 https://ip.sb
```

---

## 📊 分流规则

当你同时粘贴 Hysteria2 和 Vless-Reality 链接时：

```
┌─────────────────────────────────────────┐
│ UDP 流量 → Hysteria2 (延迟最低)         │
│ TCP 流量 → Vless-Reality (抗封锁最强)   │
│ 局域网IP → 直连                         │
└─────────────────────────────────────────┘
```

---

## 📁 生成的文件

```
~/proxy/
├── client/config.json        # sing-box 配置（自动生成）
├── client/docker-compose.yml # Docker 配置（自动生成）
├── proxy.sh           # 控制脚本
└── env.sh             # 环境变量脚本
```

---

## ❓ 常见问题

### Q: 链接解析失败？

确保链接格式正确：
- `hysteria2://` 开头
- `vless://` 开头
- 不要有多余空格

### Q: 容器启动失败？

```bash
# 查看日志
docker-compose logs

# 检查配置
cat client/config.json | python3 -m json.tool
```

### Q: 如何更新节点？

```bash
# 重新运行解析脚本
bash client/link-parser.sh

# 重启服务
cd ~/proxy && ./proxy.sh restart
```
