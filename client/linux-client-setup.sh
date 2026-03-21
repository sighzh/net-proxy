#!/bin/bash
# ============================================================
# Argosbx Linux 客户端分流配置脚本
# 支持: sing-box, v2ray, clash
# 适用: 飞牛OS, Ubuntu, Debian, CentOS 等
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置目录
CONFIG_DIR="${HOME}/.config/argosbx-client"
mkdir -p "$CONFIG_DIR"

echo "=========================================="
echo "  Argosbx Linux 客户端分流配置"
echo "=========================================="
echo

# ==================== 生成 sing-box 客户端配置 ====================
generate_singbox_config() {
    local server_ip="$1"
    local hy2_port="$2"
    local vless_port="$3"
    local uuid="$4"
    local public_key="$5"
    local short_id="$6"
    
    cat > "${CONFIG_DIR}/sing-box-client.json" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "proxy"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "local"
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
      "server": "${server_ip}",
      "server_port": ${hy2_port},
      "password": "${uuid}",
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
      "server": "${server_ip}",
      "server_port": ${vless_port},
      "uuid": "${uuid}",
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
          "public_key": "${public_key}",
          "short_id": "${short_id}"
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
        "network": "udp",
        "outbound": "hy2-udp"
      },
      {
        "network": "tcp",
        "port": [80, 443, 8080, 8443],
        "outbound": "vless-tcp"
      },
      {
        "network": "tcp",
        "outbound": "hy2-udp"
      }
    ],
    "final": "proxy",
    "auto_detect_interface": true
  }
}
EOF
    echo "✅ sing-box 配置已生成: ${CONFIG_DIR}/sing-box-client.json"
}

# ==================== 生成 v2ray 客户端配置 ====================
generate_v2ray_config() {
    local server_ip="$1"
    local hy2_port="$2"
    local vless_port="$3"
    local uuid="$4"
    local public_key="$5"
    local short_id="$6"
    
    cat > "${CONFIG_DIR}/v2ray-client.json" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 7890,
      "protocol": "http",
      "settings": {
        "udp": true
      },
      "tag": "http-in"
    },
    {
      "port": 7891,
      "protocol": "socks",
      "settings": {
        "udp": true
      },
      "tag": "socks-in"
    },
    {
      "port": 7892,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "tag": "tproxy-in"
    }
  ],
  "outbounds": [
    {
      "tag": "hy2-udp",
      "protocol": "hysteria2",
      "settings": {
        "server": "${server_ip}:${hy2_port}",
        "password": "${uuid}"
      },
      "streamSettings": {
        "network": "hysteria2",
        "security": "tls",
        "tlsSettings": {
          "serverName": "www.bing.com",
          "allowInsecure": true,
          "alpn": ["h3"]
        }
      }
    },
    {
      "tag": "vless-tcp",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${server_ip}",
            "port": ${vless_port},
            "users": [
              {
                "id": "${uuid}",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "serverName": "apple.com",
          "publicKey": "${public_key}",
          "shortId": "${short_id}",
          "fingerprint": "chrome"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "network": "udp",
        "outboundTag": "hy2-udp"
      },
      {
        "type": "field",
        "network": "tcp",
        "port": "80,443,8080",
        "outboundTag": "vless-tcp"
      },
      {
        "type": "field",
        "network": "tcp",
        "outboundTag": "hy2-udp"
      }
    ]
  }
}
EOF
    echo "✅ v2ray 配置已生成: ${CONFIG_DIR}/v2ray-client.json"
}

# ==================== 生成系统代理脚本 ====================
generate_proxy_script() {
    cat > "${CONFIG_DIR}/proxy.sh" << 'PROXY_EOF'
#!/bin/bash
# 系统代理配置脚本

HTTP_PORT=7890
SOCKS_PORT=7891

# 启用系统代理
proxy_on() {
    export http_proxy="http://127.0.0.1:${HTTP_PORT}"
    export https_proxy="http://127.0.0.1:${HTTP_PORT}"
    export all_proxy="socks5://127.0.0.1:${SOCKS_PORT}"
    export no_proxy="localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8"
    
    # Git 代理
    git config --global http.proxy "http://127.0.0.1:${HTTP_PORT}"
    git config --global https.proxy "http://127.0.0.1:${HTTP_PORT}"
    
    echo "✅ 系统代理已启用"
    echo "   HTTP: http://127.0.0.1:${HTTP_PORT}"
    echo "   SOCKS: socks5://127.0.0.1:${SOCKS_PORT}"
}

# 关闭系统代理
proxy_off() {
    unset http_proxy https_proxy all_proxy no_proxy
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo "✅ 系统代理已关闭"
}

# 查看代理状态
proxy_status() {
    if [[ -n "$http_proxy" ]]; then
        echo "系统代理: 已启用"
        echo "  http_proxy=$http_proxy"
        echo "  https_proxy=$https_proxy"
        echo "  all_proxy=$all_proxy"
    else
        echo "系统代理: 未启用"
    fi
}

case "$1" in
    on)  proxy_on ;;
    off) proxy_off ;;
    status) proxy_status ;;
    *)
        echo "用法: source $0 {on|off|status}"
        echo ""
        echo "命令说明:"
        echo "  on     - 启用系统代理"
        echo "  off    - 关闭系统代理"
        echo "  status - 查看代理状态"
        ;;
esac
PROXY_EOF
    chmod +x "${CONFIG_DIR}/proxy.sh"
    echo "✅ 系统代理脚本已生成: ${CONFIG_DIR}/proxy.sh"
}

# ==================== 生成 systemd 服务文件 ====================
generate_systemd_service() {
    local client_type="$1"
    
    cat > "${CONFIG_DIR}/argosbx-client.service" << EOF
[Unit]
Description=Argosbx Client (${client_type})
After=network.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/${client_type} run -c ${CONFIG_DIR}/${client_type}-client.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ systemd 服务文件已生成: ${CONFIG_DIR}/argosbx-client.service"
    echo ""
    echo "安装服务:"
    echo "  sudo cp ${CONFIG_DIR}/argosbx-client.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable argosbx-client"
    echo "  sudo systemctl start argosbx-client"
}

# ==================== 主函数 ====================
main() {
    echo "此脚本将生成 Linux 客户端分流配置"
    echo ""
    
    # 获取服务器信息
    read -p "服务器 IP: " SERVER_IP
    read -p "Hysteria2 端口: " HY2_PORT
    read -p "Vless-Reality 端口: " VLESS_PORT
    read -p "UUID: " UUID
    read -p "Reality Public Key: " PUBLIC_KEY
    read -p "Reality Short ID: " SHORT_ID
    
    echo ""
    echo ">>> 生成配置文件..."
    echo ""
    
    generate_singbox_config "$SERVER_IP" "$HY2_PORT" "$VLESS_PORT" "$UUID" "$PUBLIC_KEY" "$SHORT_ID"
    generate_v2ray_config "$SERVER_IP" "$HY2_PORT" "$VLESS_PORT" "$UUID" "$PUBLIC_KEY" "$SHORT_ID"
    generate_proxy_script
    generate_systemd_service "sing-box"
    
    echo ""
    echo "=========================================="
    echo "  配置完成"
    echo "=========================================="
    echo ""
    echo "配置文件目录: ${CONFIG_DIR}"
    echo ""
    echo "使用方法:"
    echo ""
    echo "1. 安装客户端:"
    echo "   # sing-box"
    echo "   wget -O /usr/local/bin/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64"
    echo "   chmod +x /usr/local/bin/sing-box"
    echo ""
    echo "2. 启动客户端:"
    echo "   sing-box run -c ${CONFIG_DIR}/sing-box-client.json"
    echo ""
    echo "3. 设置系统代理:"
    echo "   source ${CONFIG_DIR}/proxy.sh on"
    echo ""
    echo "4. 验证连接:"
    echo "   curl -x http://127.0.0.1:7890 https://ip.sb"
}

# 如果带参数则直接生成
if [[ "$1" == "generate" ]]; then
    shift
    generate_singbox_config "$@"
else
    main
fi
