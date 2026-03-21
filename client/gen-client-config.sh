#!/bin/bash
# ============================================================
# Argosbx 客户端配置快速生成器
# 用法: ./gen-client-config.sh <服务器IP> <Hysteria2端口> <Vless端口> <UUID>
# ============================================================

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数
SERVER_IP="${1:-YOUR_SERVER_IP}"
HY2_PORT="${2:-443}"
VLESS_PORT="${3:-443}"
UUID="${4:-YOUR_UUID}"
PUBLIC_KEY="${5:-YOUR_PUBLIC_KEY}"
SHORT_ID="${6:-YOUR_SHORT_ID}"

CONFIG_DIR="${HOME}/.config/sing-box"
mkdir -p "$CONFIG_DIR"

echo -e "${BLUE}=========================================="
echo "  Argosbx 客户端配置生成器"
echo -e "==========================================${NC}"
echo
echo "服务器: $SERVER_IP"
echo "Hysteria2 端口: $HY2_PORT"
echo "Vless-Reality 端口: $VLESS_PORT"
echo "UUID: $UUID"
echo

# 生成 sing-box 配置
cat > "${CONFIG_DIR}/config.json" << EOF
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
      "sniff": true
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
      "server": "${SERVER_IP}",
      "server_port": ${HY2_PORT},
      "password": "${UUID}",
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
      "server": "${SERVER_IP}",
      "server_port": ${VLESS_PORT},
      "uuid": "${UUID}",
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
          "public_key": "${PUBLIC_KEY}",
          "short_id": "${SHORT_ID}"
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
EOF

echo -e "${GREEN}✅ 配置文件已生成: ${CONFIG_DIR}/config.json${NC}"
echo

# 生成启动脚本
cat > "${CONFIG_DIR}/start.sh" << 'START_EOF'
#!/bin/bash
# 启动 sing-box 客户端

CONFIG="${HOME}/.config/sing-box/config.json"

case "$1" in
    start)
        if pgrep -f "sing-box run" > /dev/null; then
            echo "sing-box 已在运行"
        else
            nohup sing-box run -c "$CONFIG" > /tmp/sing-box.log 2>&1 &
            echo "sing-box 已启动"
            sleep 1
            ps aux | grep "sing-box run" | grep -v grep
        fi
        ;;
    stop)
        pkill -f "sing-box run"
        echo "sing-box 已停止"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if pgrep -f "sing-box run" > /dev/null; then
            echo "sing-box 运行中"
            ps aux | grep "sing-box run" | grep -v grep
        else
            echo "sing-box 未运行"
        fi
        ;;
    log)
        tail -f /tmp/sing-box.log
        ;;
    test)
        echo "测试代理连接..."
        curl -x http://127.0.0.1:7890 -s --max-time 10 https://ip.sb
        echo ""
        echo "测试延迟..."
        curl -x http://127.0.0.1:7890 -o /dev/null -s -w '延迟: %{time_total}s\n' https://www.google.com
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|log|test}"
        ;;
esac
START_EOF

chmod +x "${CONFIG_DIR}/start.sh"

echo -e "${GREEN}✅ 启动脚本已生成: ${CONFIG_DIR}/start.sh${NC}"
echo

# 生成代理环境变量脚本
cat > "${CONFIG_DIR}/proxy-env.sh" << 'PROXY_EOF'
#!/bin/bash
# 代理环境变量设置

case "$1" in
    on)
        export http_proxy=http://127.0.0.1:7890
        export https_proxy=http://127.0.0.1:7890
        export all_proxy=socks5://127.0.0.1:7891
        export no_proxy=localhost,127.0.0.1,::1,.cn
        echo "✅ 代理环境变量已设置"
        echo "HTTP_PROXY=$http_proxy"
        ;;
    off)
        unset http_proxy https_proxy all_proxy no_proxy
        echo "❌ 代理环境变量已清除"
        ;;
    status)
        if [ -n "$http_proxy" ]; then
            echo "代理状态: 开启"
            echo "HTTP_PROXY=$http_proxy"
            echo "SOCKS_PROXY=$all_proxy"
        else
            echo "代理状态: 关闭"
        fi
        ;;
    *)
        echo "用法: source $0 {on|off|status}"
        echo ""
        echo "示例:"
        echo "  source $0 on    # 开启代理"
        echo "  source $0 off   # 关闭代理"
        ;;
esac
PROXY_EOF

chmod +x "${CONFIG_DIR}/proxy-env.sh"

echo -e "${GREEN}✅ 代理环境脚本已生成: ${CONFIG_DIR}/proxy-env.sh${NC}"
echo

# 生成 systemd 服务
cat > "${CONFIG_DIR}/sing-box.service" << EOF
[Unit]
Description=sing-box client
After=network.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/sing-box run -c ${CONFIG_DIR}/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ systemd 服务文件已生成: ${CONFIG_DIR}/sing-box.service${NC}"
echo

echo "=========================================="
echo "  使用方法"
echo "=========================================="
echo
echo "1. 安装 sing-box:"
echo "   wget -O /usr/local/bin/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64"
echo "   chmod +x /usr/local/bin/sing-box"
echo
echo "2. 启动客户端:"
echo "   ${CONFIG_DIR}/start.sh start"
echo
echo "3. 设置环境代理:"
echo "   source ${CONFIG_DIR}/proxy-env.sh on"
echo
echo "4. 测试连接:"
echo "   ${CONFIG_DIR}/start.sh test"
echo
echo "5. 安装为系统服务:"
echo "   sudo cp ${CONFIG_DIR}/sing-box.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable sing-box"
echo "   sudo systemctl start sing-box"
echo
