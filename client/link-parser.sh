#!/bin/bash
# ============================================================
# 代理链接解析器 - 从协议链接自动生成配置
# 支持: hysteria2://, vless://, vmess://, tuic://
# ============================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROXY_DIR="${HOME}/proxy"
mkdir -p "$PROXY_DIR"

clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║            🔗 代理链接解析器 v2.0                          ║"
echo "║                                                            ║"
echo "║     支持协议: Hysteria2 / Vless / Vmess / Tuic            ║"
echo "║     输出格式: Docker Compose + sing-box                    ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# ==================== 解析 Hysteria2 链接 ====================
parse_hysteria2() {
    local link="$1"
    echo -e "${BLUE}[解析] Hysteria2 链接...${NC}"
    
    # 移除 hysteria2:// 前缀
    local content="${link#hysteria2://}"
    
    # 提取密码
    local password="${content%%@*}"
    
    # 提取服务器和端口
    local server_port="${content#*@}"
    server_port="${server_port%%\?*}"
    local server="${server_port%:*}"
    local port="${server_port##*:}"
    
    # 提取参数
    local params="${content#*\?}"
    local name="${params##*#}"
    params="${params%#*}"
    
    # 解析参数
    local sni="www.bing.com"
    if [[ "$params" == *"sni="* ]]; then
        sni=$(echo "$params" | grep -oP 'sni=\K[^&]*')
    fi
    
    echo -e "  ${GREEN}✓${NC} 服务器: ${CYAN}${server}${NC}"
    echo -e "  ${GREEN}✓${NC} 端口: ${CYAN}${port}${NC}"
    echo -e "  ${GREEN}✓${NC} 密码: ${CYAN}${password:0:8}...${NC}"
    echo -e "  ${GREEN}✓${NC} SNI: ${CYAN}${sni}${NC}"
    echo -e "  ${GREEN}✓${NC} 名称: ${CYAN}${name}${NC}"
    
    echo "SERVER=$server"
    echo "PORT=$port"
    echo "PASSWORD=$password"
    echo "SNI=$sni"
}

# ==================== 解析 Vless 链接 ====================
parse_vless() {
    local link="$1"
    echo -e "${BLUE}[解析] Vless-Reality 链接...${NC}"
    
    local content="${link#vless://}"
    
    # 提取 UUID
    local uuid="${content%%@*}"
    
    # 提取服务器和端口
    local server_port="${content#*@}"
    server_port="${server_port%%\?*}"
    local server="${server_port%:*}"
    local port="${server_port##*:}"
    
    # 提取参数
    local params="${content#*\?}"
    local name="${params##*#}"
    params="${params%#*}"
    
    # 解析参数
    local sni="apple.com"
    local public_key=""
    local short_id=""
    local flow="xtls-rprx-vision"
    
    if [[ "$params" == *"sni="* ]]; then
        sni=$(echo "$params" | grep -oP 'sni=\K[^&]*' || echo "apple.com")
    fi
    
    if [[ "$params" == *"pbk="* ]]; then
        public_key=$(echo "$params" | grep -oP 'pbk=\K[^&]*')
    fi
    
    if [[ "$params" == *"sid="* ]]; then
        short_id=$(echo "$params" | grep -oP 'sid=\K[^&]*')
    fi
    
    echo -e "  ${GREEN}✓${NC} 服务器: ${CYAN}${server}${NC}"
    echo -e "  ${GREEN}✓${NC} 端口: ${CYAN}${port}${NC}"
    echo -e "  ${GREEN}✓${NC} UUID: ${CYAN}${uuid:0:8}...${NC}"
    echo -e "  ${GREEN}✓${NC} SNI: ${CYAN}${sni}${NC}"
    echo -e "  ${GREEN}✓${NC} 公钥: ${CYAN}${public_key}${NC}"
    echo -e "  ${GREEN}✓${NC} 短ID: ${CYAN}${short_id}${NC}"
    echo -e "  ${GREEN}✓${NC} 名称: ${CYAN}${name}${NC}"
    
    echo "SERVER=$server"
    echo "PORT=$port"
    echo "UUID=$uuid"
    echo "SNI=$sni"
    echo "PUBLIC_KEY=$public_key"
    echo "SHORT_ID=$short_id"
}

# ==================== 生成配置 ====================
generate_config() {
    local hy2_vars="$1"
    local vless_vars="$2"
    
    echo
    echo -e "${BLUE}[生成] 配置文件...${NC}"
    
    # 解析变量
    eval "$hy2_vars"
    local hy2_server="$SERVER"
    local hy2_port="$PORT"
    local hy2_password="$PASSWORD"
    local hy2_sni="$SNI"
    
    eval "$vless_vars"
    local vless_server="$SERVER"
    local vless_port="$PORT"
    local vless_uuid="$UUID"
    local vless_sni="$SNI"
    local vless_public_key="$PUBLIC_KEY"
    local vless_short_id="$SHORT_ID"
    
    # 生成 docker-compose.yml
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
    echo -e "  ${GREEN}✓${NC} docker-compose.yml"
    
    # 生成 config.json
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
      "server": "${hy2_server}",
      "server_port": ${hy2_port},
      "password": "${hy2_password}",
      "tls": {
        "enabled": true,
        "server_name": "${hy2_sni}",
        "insecure": true,
        "alpn": ["h3"]
      }
    },
    {
      "type": "vless",
      "tag": "vless-tcp",
      "server": "${vless_server}",
      "server_port": ${vless_port},
      "uuid": "${vless_uuid}",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "${vless_sni}",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": {
          "enabled": true,
          "public_key": "${vless_public_key}",
          "short_id": "${vless_short_id}"
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
      {
        "type": "logical",
        "mode": "or",
        "rules": [
          { "domain_suffix": [".cn", ".中国", ".公司", ".网络"] },
          { "domain_keyword": ["baidu", "taobao", "tmall", "jd", "qq", "weixin", "weibo", "aliyun", "alipay", "163", "126", "sina", "sohu", "youku", "iqiyi", "bilibili", "douyin", "csdn", "zhihu", "meituan"] },
          { "ip_cidr": ["223.5.5.5/32", "119.29.29.29/32", "180.76.76.76/32"] }
        ],
        "outbound": "direct"
      },
      { "network": "udp", "outbound": "hy2-udp" },
      { "network": "tcp", "outbound": "vless-tcp" }
    ],
    "final": "proxy"
  }
}
EOF
    echo -e "  ${GREEN}✓${NC} config.json"
    
    # 生成控制脚本
    cat > "${PROXY_DIR}/proxy.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd "$(dirname "$0")"
case "$1" in
    start)
        docker-compose up -d
        echo "✅ 代理已启动"
        echo "   HTTP:  http://127.0.0.1:7890"
        echo "   SOCKS: socks5://127.0.0.1:7891"
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
        docker-compose logs -f --tail=50
        ;;
    test)
        echo "测试代理连接..."
        echo ""
        curl -x http://127.0.0.1:7890 -s --max-time 10 https://ip.sb && echo ""
        echo ""
        echo "测试延迟..."
        curl -x http://127.0.0.1:7890 -o /dev/null -s -w '延迟: %{time_total}s\n' https://www.google.com
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|test}"
        ;;
esac
SCRIPT_EOF
    chmod +x "${PROXY_DIR}/proxy.sh"
    echo -e "  ${GREEN}✓${NC} proxy.sh"
    
    # 生成环境变量脚本
    cat > "${PROXY_DIR}/env.sh" << 'ENV_EOF'
#!/bin/bash
case "$1" in
    on)
        export http_proxy=http://127.0.0.1:7890
        export https_proxy=http://127.0.0.1:7890
        export all_proxy=socks5://127.0.0.1:7891
        export no_proxy=localhost,127.0.0.1,.cn
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
    echo -e "  ${GREEN}✓${NC} env.sh"
}

# ==================== 主程序 ====================
main() {
    echo -e "${YELLOW}请粘贴节点链接（支持多个，一行一个，空行结束）：${NC}"
    echo
    echo -e "${CYAN}示例:${NC}"
    echo "  hysteria2://uuid@server:port?..."
    echo "  vless://uuid@server:port?..."
    echo
    
    HY2_VARS=""
    VLESS_VARS=""
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        
        link=$(echo "$line" | tr -d '[:space:]')
        
        if [[ "$link" == hysteria2://* ]]; then
            HY2_VARS=$(parse_hysteria2 "$link")
            echo
        elif [[ "$link" == vless://* ]]; then
            VLESS_VARS=$(parse_vless "$link")
            echo
        elif [[ "$link" == vmess://* ]]; then
            echo -e "${YELLOW}[跳过] Vmess 暂不支持${NC}"
            echo
        elif [[ "$link" == tuic://* ]]; then
            echo -e "${YELLOW}[跳过] Tuic 暂不支持${NC}"
            echo
        else
            echo -e "${RED}[错误] 未知协议: ${link:0:30}...${NC}"
            echo
        fi
    done
    
    if [[ -z "$HY2_VARS" && -z "$VLESS_VARS" ]]; then
        echo -e "${RED}[错误] 未识别到有效链接${NC}"
        exit 1
    fi
    
    # 生成配置
    generate_config "$HY2_VARS" "$VLESS_VARS"
    
    # 显示完成信息
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ 配置完成                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "📁 目录: ${CYAN}${PROXY_DIR}${NC}"
    echo
    echo -e "${YELLOW}分流规则:${NC}"
    echo -e "  UDP → Hysteria2 (延迟最低)"
    echo -e "  TCP → Vless-Reality (抗封锁)"
    echo
    echo -e "${YELLOW}启动命令:${NC}"
    echo -e "  cd ${PROXY_DIR} && ./proxy.sh start"
    echo
    echo -e "${YELLOW}代理地址:${NC}"
    echo -e "  HTTP:  ${CYAN}http://127.0.0.1:7890${NC}"
    echo -e "  SOCKS: ${CYAN}socks5://127.0.0.1:7891${NC}"
    echo
    
    # 询问是否启动
    read -p "是否立即启动代理? (y/n): " START_NOW
    if [[ "$START_NOW" == "y" ]]; then
        cd "$PROXY_DIR"
        ./proxy.sh start
        sleep 3
        ./proxy.sh test
    fi
}

main
