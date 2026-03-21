#!/bin/bash
# ============================================================
# 飞牛OS (fnOS) / Docker 一键代理配置脚本
# 用法: bash fnos-proxy-setup.sh
# ============================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置目录
PROXY_DIR="${HOME}/proxy"
mkdir -p "$PROXY_DIR"

echo -e "${BLUE}"
echo "=========================================="
echo "  飞牛OS / Docker 一键代理配置"
echo "=========================================="
echo -e "${NC}"
echo

# ==================== 获取配置信息 ====================
echo -e "${YELLOW}请输入服务器配置信息：${NC}"
echo

read -p "服务器 IP 地址: " SERVER_IP
read -p "Hysteria2 端口 (默认443): " HY2_PORT
HY2_PORT=${HY2_PORT:-443}

read -p "Vless-Reality 端口 (默认443): " VLESS_PORT
VLESS_PORT=${VLESS_PORT:-443}

read -p "UUID 密码: " UUID

echo
echo -e "${YELLOW}Vless-Reality 配置 (如无请留空):${NC}"
read -p "Reality 公钥: " PUBLIC_KEY
read -p "Reality 短ID: " SHORT_ID

echo
echo "=========================================="
echo "  配置确认"
echo "=========================================="
echo "服务器: $SERVER_IP"
echo "Hysteria2 端口: $HY2_PORT"
echo "Vless-Reality 端口: $VLESS_PORT"
echo "UUID: $UUID"
[ -n "$PUBLIC_KEY" ] && echo "Reality 公钥: $PUBLIC_KEY"
[ -n "$SHORT_ID" ] && echo "Reality 短ID: $SHORT_ID"
echo

read -p "确认配置正确? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "已取消"
    exit 1
fi

# ==================== 生成配置文件 ====================
echo
echo -e "${GREEN}>>> 生成配置文件...${NC}"

# 判断是双协议还是单协议
if [[ -n "$PUBLIC_KEY" && -n "$SHORT_ID" ]]; then
    # 双协议模式
    cat > "${PROXY_DIR}/config.json" << EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "remote-dns", "address": "https://1.1.1.1/dns-query", "detour": "proxy" },
      { "tag": "local-dns", "address": "223.5.5.5", "detour": "direct" }
    ],
    "rules": [{ "outbound": "any", "server": "local-dns" }],
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
      "listen": "0.0.0.0",
      "listen_port": 7890
    },
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
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
        "utls": { "enabled": true, "fingerprint": "chrome" },
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
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" },
    { "type": "dns", "tag": "dns-out" }
  ],
  "route": {
    "rules": [
      { "protocol": "dns", "outbound": "dns-out" },
      { "ip_is_private": true, "outbound": "direct" },
      { "network": "udp", "outbound": "hy2-udp" },
      { "network": "tcp", "outbound": "vless-tcp" }
    ],
    "final": "proxy"
  }
}
EOF
    echo -e "${GREEN}✅ 双协议配置已生成 (UDP→Hysteria2, TCP→Vless-Reality)${NC}"
else
    # 单协议模式 (仅 Hysteria2)
    cat > "${PROXY_DIR}/config.json" << EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "remote-dns", "address": "https://1.1.1.1/dns-query", "detour": "proxy" },
      { "tag": "local-dns", "address": "223.5.5.5", "detour": "direct" }
    ],
    "rules": [{ "outbound": "any", "server": "local-dns" }],
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
      "listen": "0.0.0.0",
      "listen_port": 7890
    },
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": 7891
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "proxy",
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
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" },
    { "type": "dns", "tag": "dns-out" }
  ],
  "route": {
    "rules": [
      { "protocol": "dns", "outbound": "dns-out" },
      { "ip_is_private": true, "outbound": "direct" }
    ],
    "final": "proxy"
  }
}
EOF
    echo -e "${GREEN}✅ 单协议配置已生成 (Hysteria2)${NC}"
fi

# ==================== 生成 docker-compose.yml ====================
cat > "${PROXY_DIR}/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  sing-box:
    image: ghcr.io/sagernet/sing-box:latest
    container_name: sing-box-proxy
    restart: always
    network_mode: host
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config.json:/etc/sing-box/config.json:ro
    environment:
      - TZ=Asia/Shanghai
    command: run -c /etc/sing-box/config.json
EOF

echo -e "${GREEN}✅ docker-compose.yml 已生成${NC}"

# ==================== 生成控制脚本 ====================
cat > "${PROXY_DIR}/proxy.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd "$(dirname "$0")"

case "$1" in
    start)
        docker-compose up -d
        echo "✅ 代理已启动"
        ;;
    stop)
        docker-compose down
        echo "❌ 代理已停止"
        ;;
    restart)
        docker-compose restart
        echo "🔄 代理已重启"
        ;;
    status)
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f
        ;;
    test)
        echo "测试代理连接..."
        curl -x http://127.0.0.1:7890 -s --max-time 10 https://ip.sb && echo ""
        echo "测试延迟..."
        curl -x http://127.0.0.1:7890 -o /dev/null -s -w '延迟: %{time_total}s\n' https://www.google.com
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|test}"
        ;;
esac
SCRIPT_EOF

chmod +x "${PROXY_DIR}/proxy.sh"
echo -e "${GREEN}✅ 控制脚本已生成${NC}"

# ==================== 生成环境变量脚本 ====================
cat > "${PROXY_DIR}/env.sh" << 'ENV_EOF'
#!/bin/bash
case "$1" in
    on)
        export http_proxy=http://127.0.0.1:7890
        export https_proxy=http://127.0.0.1:7890
        export all_proxy=socks5://127.0.0.1:7891
        export no_proxy=localhost,127.0.0.1,::1,.cn,192.168.0.0/16,10.0.0.0/8
        echo "✅ 代理环境变量已设置"
        ;;
    off)
        unset http_proxy https_proxy all_proxy no_proxy
        echo "❌ 代理环境变量已清除"
        ;;
    status)
        [ -n "$http_proxy" ] && echo "代理: 开启 ($http_proxy)" || echo "代理: 关闭"
        ;;
    *)
        echo "用法: source $0 {on|off|status}"
        ;;
esac
ENV_EOF

chmod +x "${PROXY_DIR}/env.sh"
echo -e "${GREEN}✅ 环境变量脚本已生成${NC}"

# ==================== 启动服务 ====================
echo
echo -e "${GREEN}>>> 启动代理服务...${NC}"
cd "$PROXY_DIR"
docker-compose up -d

sleep 3

echo
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo
echo "📁 配置目录: $PROXY_DIR"
echo
echo "🔧 控制命令:"
echo "   ./proxy.sh start    # 启动"
echo "   ./proxy.sh stop     # 停止"
echo "   ./proxy.sh restart  # 重启"
echo "   ./proxy.sh status   # 状态"
echo "   ./proxy.sh logs     # 日志"
echo "   ./proxy.sh test     # 测试"
echo
echo "🌐 代理地址:"
echo "   HTTP:  http://127.0.0.1:7890"
echo "   SOCKS: socks5://127.0.0.1:7891"
echo
echo "💡 设置系统代理:"
echo "   source $PROXY_DIR/env.sh on"
echo
echo "🧪 测试连接:"
echo "   curl -x http://127.0.0.1:7890 https://ip.sb"
echo

# 测试连接
echo ">>> 自动测试连接..."
sleep 2
if curl -x http://127.0.0.1:7890 -s --max-time 10 https://ip.sb 2>/dev/null; then
    echo ""
    echo -e "${GREEN}✅ 代理连接成功！${NC}"
else
    echo -e "${YELLOW}⚠️ 代理连接测试失败，请检查配置${NC}"
fi
