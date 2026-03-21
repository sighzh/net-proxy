# Linux 客户端分流配置指南

## 一、客户端软件选择

| 软件 | 推荐度 | 特点 | 适用场景 |
|------|:------:|------|----------|
| **sing-box** | ⭐⭐⭐ | 全协议支持、性能好 | 服务器、NAS、桌面 |
| **v2ray** | ⭐⭐ | 成熟稳定 | 服务器 |
| **clash** | ⭐⭐ | 规则丰富 | 桌面 |
| **xray** | ⭐⭐ | Xray内核 | 服务器 |

---

## 二、sing-box 客户端配置（推荐）

### 1. 安装 sing-box

```bash
# 下载最新版本
wget -O /usr/local/bin/sing-box \
  https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64

chmod +x /usr/local/bin/sing-box

# 验证安装
sing-box version
```

### 2. 创建配置文件

```bash
mkdir -p ~/.config/sing-box
nano ~/.config/sing-box/config.json
```

### 3. 完整分流配置

```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "proxy-dns",
        "address": "https://1.1.1.1/dns-query",
        "detour": "hy2-udp"
      },
      {
        "tag": "local-dns",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "local-dns"
      },
      {
        "clash_mode": "direct",
        "server": "local-dns"
      }
    ],
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": true,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": true
    },
    {
      "type": "http",
      "tag": "http-in",
      "listen": "127.0.0.1",
      "listen_port": 7890
    },
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "127.0.0.1",
      "listen_port": 7891
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-udp",
      "server": "YOUR_SERVER_IP",
      "server_port": 443,
      "password": "YOUR_UUID",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": ["h3"]
      }
    },
    {
      "type": "vless",
      "tag": "vless-tcp",
      "server": "YOUR_SERVER_IP",
      "server_port": 443,
      "uuid": "YOUR_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "apple.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "YOUR_PUBLIC_KEY",
          "short_id": "YOUR_SHORT_ID"
        }
      }
    },
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["hy2-udp", "vless-tcp"],
      "default": "hy2-udp"
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "network": "udp",
        "outbound": "hy2-udp"
      },
      {
        "network": "tcp",
        "outbound": "vless-tcp"
      }
    ],
    "final": "proxy"
  }
}
```

### 4. 启动服务

```bash
# 前台运行（测试）
sing-box run -c ~/.config/sing-box/config.json

# 后台运行
nohup sing-box run -c ~/.config/sing-box/config.json > /var/log/sing-box.log 2>&1 &
```

### 5. 创建 systemd 服务

```bash
sudo tee /etc/systemd/system/sing-box.service << 'EOF'
[Unit]
Description=sing-box client
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /root/.config/sing-box/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable sing-box
sudo systemctl start sing-box
```

---

## 三、分流规则详解

### 1. TCP/UDP 分流

```json
{
  "route": {
    "rules": [
      {
        "network": "udp",
        "outbound": "hy2-udp"
      },
      {
        "network": "tcp",
        "outbound": "vless-tcp"
      }
    ],
    "final": "hy2-udp"
  }
}
```

### 2. 按端口分流

```json
{
  "route": {
    "rules": [
      {
        "network": "udp",
        "port": [443, 8443],
        "outbound": "hy2-udp"
      },
      {
        "network": "tcp",
        "port": [80, 443],
        "outbound": "vless-tcp"
      },
      {
        "port": [22, 3389],
        "outbound": "direct"
      }
    ],
    "final": "proxy"
  }
}
```

### 3. 按进程分流

```json
{
  "route": {
    "rules": [
      {
        "process_name": ["chrome", "firefox"],
        "outbound": "hy2-udp"
      },
      {
        "process_name": ["wget", "curl", "apt", "yum"],
        "outbound": "vless-tcp"
      }
    ],
    "final": "proxy"
  }
}
```

### 4. 按域名分流

```json
{
  "route": {
    "rules": [
      {
        "domain_suffix": [".cn", ".中国"],
        "outbound": "direct"
      },
      {
        "domain_keyword": ["google", "youtube", "github"],
        "outbound": "hy2-udp"
      },
      {
        "domain_suffix": [".edu", ".gov"],
        "outbound": "vless-tcp"
      }
    ],
    "final": "proxy"
  }
}
```

---

## 四、系统代理配置

### 1. 环境变量方式

```bash
# 临时设置
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7891

# 永久设置（添加到 ~/.bashrc）
echo 'export http_proxy=http://127.0.0.1:7890' >> ~/.bashrc
echo 'export https_proxy=http://127.0.0.1:7890' >> ~/.bashrc
echo 'export all_proxy=socks5://127.0.0.1:7891' >> ~/.bashrc
source ~/.bashrc
```

### 2. 代理开关脚本

```bash
# 创建代理开关
tee ~/proxy.sh << 'EOF'
#!/bin/bash
case "$1" in
    on)
        export http_proxy=http://127.0.0.1:7890
        export https_proxy=http://127.0.0.1:7890
        export all_proxy=socks5://127.0.0.1:7891
        echo "✅ 代理已开启"
        ;;
    off)
        unset http_proxy https_proxy all_proxy
        echo "❌ 代理已关闭"
        ;;
    status)
        if [ -n "$http_proxy" ]; then
            echo "代理状态: 开启"
            echo "HTTP: $http_proxy"
            echo "SOCKS: $all_proxy"
        else
            echo "代理状态: 关闭"
        fi
        ;;
    test)
        curl -s --max-time 5 https://ip.sb && echo "代理连接正常"
        ;;
    *)
        echo "用法: source ~/proxy.sh {on|off|status|test}"
        ;;
esac
EOF

chmod +x ~/proxy.sh
```

---

## 五、飞牛OS (fnOS) 配置

### 1. Docker 方式（推荐）

```bash
# 创建配置目录
mkdir -p /vol1/@appstore/sing-box/config

# 创建 docker-compose.yml
cat > /vol1/@appstore/sing-box/docker-compose.yml << 'EOF'
version: '3'
services:
  sing-box:
    image: ghcr.io/sagernet/sing-box:latest
    container_name: sing-box
    restart: always
    network_mode: host
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/sing-box:ro
    command: run -c /etc/sing-box/config.json
EOF

# 创建配置文件
cat > /vol1/@appstore/sing-box/config/config.json << 'EOF'
{
  "log": {"level": "info"},
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": true,
      "stack": "system"
    },
    {
      "type": "http",
      "tag": "http-in",
      "listen": "0.0.0.0",
      "listen_port": 7890
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "proxy",
      "server": "YOUR_SERVER_IP",
      "server_port": 443,
      "password": "YOUR_UUID",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {"ip_is_private": true, "outbound": "direct"}
    ],
    "final": "proxy"
  }
}
EOF

# 启动
cd /vol1/@appstore/sing-box
docker-compose up -d
```

### 2. 系统代理设置

```bash
# 飞牛OS 设置系统代理
# 方法1: 在 Web 界面设置
# 控制面板 -> 网络 -> 代理 -> 手动代理
# HTTP代理: 127.0.0.1 端口: 7890

# 方法2: 命令行设置
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
```

---

## 六、验证连接

### 1. 检查服务状态

```bash
# 检查 sing-box 进程
ps aux | grep sing-box

# 检查端口监听
ss -tlnp | grep -E "7890|7891"

# 查看日志
journalctl -u sing-box -f
```

### 2. 测试连接

```bash
# 测试 HTTP 代理
curl -x http://127.0.0.1:7890 https://ip.sb

# 测试 SOCKS 代理
curl -x socks5://127.0.0.1:7891 https://ip.sb

# 测试延迟
curl -x http://127.0.0.1:7890 -o /dev/null -s -w '%{time_total}s\n' https://www.google.com
```

### 3. 测试分流

```bash
# 测试 UDP 分流（应该走 Hysteria2）
curl -x http://127.0.0.1:7890 https://speed.cloudflare.com/__down?bytes=10000000 -o /dev/null

# 测试 TCP 分流（应该走 Vless-Reality）
curl -x http://127.0.0.1:7890 https://www.baidu.com -I
```

---

## 七、常见问题

### Q1: TUN 模式需要 root 权限

```bash
# 使用 sudo 运行
sudo sing-box run -c ~/.config/sing-box/config.json

# 或使用 HTTP/SOCKS 模式（无需 root）
# 只使用 http-in 和 socks-in 入站
```

### Q2: DNS 解析失败

```json
{
  "dns": {
    "servers": [
      {"tag": "remote", "address": "https://1.1.1.1/dns-query"},
      {"tag": "local", "address": "223.5.5.5"}
    ],
    "rules": [
      {"outbound": "any", "server": "local"}
    ]
  }
}
```

### Q3: 部分应用不走代理

```bash
# 使用 proxychains 强制走代理
sudo apt install proxychains4
echo 'socks5 127.0.0.1 7891' >> /etc/proxychains4.conf

# 使用
proxychains4 curl https://ip.sb
```

### Q4: Docker 容器使用代理

```bash
# 配置 Docker 代理
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/proxy.conf << 'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,.cn"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```
