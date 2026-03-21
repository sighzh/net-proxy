# 客户端使用说明

## 📋 基本信息

### 端口说明

| 端口 | 协议 | 用途 |
|------|------|------|
| `7890` | HTTP | HTTP代理端口 |
| `7891` | SOCKS5 | SOCKS代理端口 |

### 网络模式

本项目使用 **host 网络模式**：

```
network_mode: host
```

**优点**：
- ✅ 性能最佳，无网络开销
- ✅ 无需端口映射
- ✅ 支持 TUN 模式（全局代理）

**注意**：
- ⚠️ 宿主机端口 7890/7891 不能被占用
- ⚠️ 需要 NET_ADMIN 权限（已配置）

---

## 🌐 代理地址

### HTTP 代理
```
http://127.0.0.1:7890
```

### SOCKS5 代理
```
socks5://127.0.0.1:7891
```

---

## 📝 直连白名单

以下流量自动直连，不走代理：

### 国内域名后缀
```
.cn, .中国, .公司, .网络
```

### 国内常用网站
```
baidu, taobao, tmall, jd, qq, weixin, weibo
aliyun, alipay, 163, 126, sina, sohu
youku, iqiyi, bilibili, douyin
csdn, zhihu, jianshu, douban
meituan, dianping, eleme
```

### 国内 DNS
```
223.5.5.5, 119.29.29.29, 180.76.76.76, 114.114.114.114
```

### 私有 IP
```
192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12
```

---

## 🚀 使用方法

### 方法一：环境变量

```bash
# 临时设置
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7891

# 测试
curl https://ip.sb
```

### 方法二：命令行指定

```bash
# HTTP代理
curl -x http://127.0.0.1:7890 https://ip.sb

# SOCKS代理
curl -x socks5://127.0.0.1:7891 https://ip.sb

# wget
wget -e http_proxy=http://127.0.0.1:7890 https://example.com

# git
git config --global http.proxy http://127.0.0.1:7890
```

### 方法三：系统代理

```bash
# 使用提供的脚本
source ~/proxy/env.sh on   # 开启
source ~/proxy/env.sh off  # 关闭
```

### 方法四：Docker 容器

```bash
# 配置 Docker 代理
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,.cn"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 📊 分流规则

```
┌─────────────────────────────────────────────────────────────┐
│                        流量分流                              │
├─────────────────────────────────────────────────────────────┤
│  国内网站/域名 → 直连（不走代理）                            │
│  私有IP地址   → 直连                                         │
│  UDP 流量    → Hysteria2（延迟最低）                         │
│  TCP 流量    → Vless-Reality（抗封锁）                       │
│  其他流量    → 代理                                          │
└─────────────────────────────────────────────────────────────┘
```

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

## ❓ 常见问题

### Q1: 端口被占用？

```bash
# 检查端口占用
ss -tlnp | grep -E "7890|7891"

# 停止占用进程
kill <PID>
```

### Q2: 无法连接？

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs sing-box-proxy

# 检查配置
cat config.json | python3 -m json.tool
```

### Q3: 部分网站无法访问？

检查是否在直连白名单中，可以编辑 `config.json` 添加或删除规则。

### Q4: 如何添加直连域名？

编辑 `config.json`，在 `domain_keyword` 或 `domain_suffix` 中添加：

```json
{ "domain_keyword": ["新域名关键词"] }
```

---

## ⚠️ 注意事项

1. **host 模式**：容器直接使用宿主机网络
2. **端口冲突**：确保 7890/7891 未被占用
3. **权限要求**：需要 NET_ADMIN 权限（TUN模式）
4. **直连白名单**：国内网站自动直连，节省流量
