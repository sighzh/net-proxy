#!/bin/bash
# ============================================================
# 自研 VPS 代理服务端部署脚本 v1.0
# 
# 功能：在 VPS 上部署 sing-box，支持 Vless-Reality + Hysteria2 双协议
# 依赖：无（自包含，自动下载 sing-box）
# 
# 用法：
#   bash self-deploy.sh
#   或通过环境变量配置：
#   HY_PORT=443 VL_PORT=4433 bash self-deploy.sh
#
# 环境变量：
#   HY_PORT    - Hysteria2 端口 (默认: 443)
#   VL_PORT    - Vless-Reality 端口 (默认: 4433)
#   UUID       - Vless UUID (自动生成)
#   REALITY_PRIVATE_KEY - Reality 私钥 (自动生成)
#   INSTALL_DIR - 安装目录 (默认: /root/agsbx)
#   ENABLE_BBR  - 启用 BBR (默认: 1)
#   LISTEN_ADDR - 监听地址 (默认: 自动检测的公网IP)
# ============================================================
set -euo pipefail
export LANG=en_US.UTF-8

# ==================== 配置变量 ====================
INSTALL_DIR="${INSTALL_DIR:-/root/agsbx}"
HY_PORT="${HY_PORT:-443}"
VL_PORT="${VL_PORT:-4433}"
ENABLE_BBR="${ENABLE_BBR:-1}"
SINGBOX_VERSION="1.10.0"
LISTEN_ADDR="${LISTEN_ADDR:-}"

# 自动检测 IP
get_public_ip() {
    local ip=""
    for service in "https://api.ipify.org" "https://icanhazip.com" "https://ipinfo.io/ip"; do
        ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | tr -d '\n' || true)
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    echo ""
    return 1
}

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ==================== 系统检测 ====================
detect_system() {
    log_step "检测系统环境..."
    
    # 检测架构
    case $(uname -m) in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) log_error "不支持的架构: $(uname -m)"; exit 1 ;;
    esac
    
    # 检测系统
    if [ -f /etc/os-release ]; then
        OS=$(grep '^ID=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        PRETTY_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
        if [ -n "$PRETTY_NAME" ]; then
            log_info "系统: $PRETTY_NAME"
        fi
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        log_info "系统: $(cat /etc/redhat-release)"
    else
        OS="unknown"
        log_warn "无法检测系统版本"
    fi
    
    log_info "架构: $ARCH"
}

# ==================== 安装依赖 ====================
install_deps() {
    log_step "安装依赖..."
    
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq curl wget unzip jq >/dev/null 2>&1
            ;;
        centos|rhel|fedora)
            yum install -y -q curl wget unzip jq >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache curl wget unzip jq >/dev/null 2>&1
            ;;
        *)
            log_warn "未知系统，尝试继续..."
            ;;
    esac
    
    log_info "依赖安装完成"
}

# ==================== BBR 优化 ====================
install_bbr() {
    if [ "$ENABLE_BBR" != "1" ]; then
        log_info "BBR 优化已禁用"
        return
    fi
    
    log_step "配置 BBR 网络优化..."
    
    # 检查内核版本
    KERNEL_VER=$(uname -r | cut -d'-' -f1)
    KERNEL_MAJOR=$(echo "$KERNEL_VER" | cut -d'.' -f1)
    KERNEL_MINOR=$(echo "$KERNEL_VER" | cut -d'.' -f2)
    
    if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
        log_warn "内核版本过低 ($KERNEL_VER)，BBR 需要 4.9+ 内核"
        return
    fi
    
    # 加载 BBR 模块
    modprobe tcp_bbr 2>/dev/null || true
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null || true
    
    # 应用 sysctl 配置
    cat > /etc/sysctl.d/99-bbr.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
fs.file-max = 1048576
EOF
    
    sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null 2>&1 || true
    
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [ "$cc" = "bbr" ]; then
        log_info "BBR 已启用"
    else
        log_warn "BBR 启用失败，当前: $cc"
    fi
}

# ==================== 生成密钥 ====================
generate_keys() {
    log_step "生成密钥..."
    
    # 生成 UUID
    if [ -z "${UUID:-}" ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    fi
    log_info "UUID: $UUID"
    
    # 生成 Reality 密钥对
    if [ -z "${REALITY_PRIVATE_KEY:-}" ]; then
        # 使用 sing-box 生成密钥对（稍后下载后生成）
        REALITY_PRIVATE_KEY=""
        REALITY_PUBLIC_KEY=""
    fi
}

# ==================== 下载 sing-box ====================
download_singbox() {
    log_step "下载 sing-box v${SINGBOX_VERSION}..."
    
    local TMPDIR=$(mktemp -d)
    trap "rm -rf '$TMPDIR'" EXIT
    
    local filename="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    local url="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${filename}"
    local checksum_url="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/checksums.txt"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "${TMPDIR}/${filename}" "$url" || \
        wget -q -O "${TMPDIR}/${filename}" "$url"
    else
        curl -L -o "${TMPDIR}/${filename}" "$url" --progress-bar
    fi
    
    # SHA256 校验
    log_step "验证 SHA256 校验..."
    local checksum_line
    checksum_line=$(curl -sL "$checksum_url" | grep "${filename}" || true)
    if [ -n "$checksum_line" ]; then
        local expected_checksum
        expected_checksum=$(echo "$checksum_line" | awk '{print $1}')
        local actual_checksum
        actual_checksum=$(sha256sum "${TMPDIR}/${filename}" | awk '{print $1}')
        if [ "$expected_checksum" = "$actual_checksum" ]; then
            log_info "SHA256 校验通过: $expected_checksum"
        else
            log_error "SHA256 校验失败！"
            log_error "期望: $expected_checksum"
            log_error "实际: $actual_checksum"
            rm -rf "$TMPDIR"
            exit 1
        fi
    else
        log_warn "无法获取 checksums.txt，跳过校验（警告：降低了安全性）"
    fi
    
    tar -xzf "${TMPDIR}/${filename}" -C "$TMPDIR/"
    cp "${TMPDIR}/sing-box-${SINGBOX_VERSION}-linux-${ARCH}/sing-box" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/sing-box"
    
    log_info "sing-box 已安装到 $INSTALL_DIR/sing-box"
}

# ==================== 生成 Reality 密钥 ====================
generate_reality_keys() {
    if [ -z "$REALITY_PRIVATE_KEY" ]; then
        log_step "生成 Reality 密钥对..."
        local key_output=$("$INSTALL_DIR/sing-box" generate reality-keypair)
        REALITY_PRIVATE_KEY=$(echo "$key_output" | grep -oP 'Private key: \K.*')
        REALITY_PUBLIC_KEY=$(echo "$key_output" | grep -oP 'Public key: \K.*')
        log_info "Reality Public Key: $REALITY_PUBLIC_KEY"
    fi
}

# ==================== 生成配置 ====================
generate_config() {
    log_step "生成 sing-box 配置..."
    
    local SERVER_IP="$1"
    
    # 监听地址（默认绑定公网IP，避免暴露到所有接口）
    local LISTEN="${LISTEN_ADDR:-$SERVER_IP}"
    
    # 生成随机短 ID
    local SHORT_ID=$(openssl rand -hex 4)
    
    # 生成 Hysteria2 密码
    local HY_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
    
    # 生成 Hysteria2 obfs 密码（一次性生成，config.json 和 nodes.txt 共用）
    local OBFS_PASSWORD=$(openssl rand -hex 4)
    
    cat > "$INSTALL_DIR/config.json" << EOF
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "hysteria2",
            "tag": "hysteria2-in",
            "listen": "$LISTEN",
            "listen_port": $HY_PORT,
            "obfs": {
                "type": "salamander",
                "password": "$OBFS_PASSWORD"
            },
            "password": "$HY_PASSWORD",
            "masquerade": "https://www.bing.com"
        },
        {
            "type": "vless",
            "tag": "vless-reality-in",
            "listen": "$LISTEN",
            "listen_port": $VL_PORT,
            "users": [
                {
                    "uuid": "$UUID",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "www.microsoft.com",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.microsoft.com",
                        "server_port": 443
                    },
                    "private_key": "$REALITY_PRIVATE_KEY",
                    "short_id": "$SHORT_ID"
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ],
    "route": {
        "rules": [
            {
                "geosite": ["category-ads-all"],
                "outbound": "block"
            }
        ],
        "auto_detect_interface": true
    }
}
EOF
    
    # 设置配置文件权限（包含私钥，必须 600）
    chmod 600 "$INSTALL_DIR/config.json"
    log_info "配置已生成: $INSTALL_DIR/config.json"
    
    # 保存节点信息
    cat > "$INSTALL_DIR/nodes.txt" << EOF
# 节点信息 - 生成于 $(date)
# 服务器: $SERVER_IP

## Hysteria2
hysteria2://$HY_PASSWORD@$SERVER_IP:$HY_PORT/?obfs=salamander&obfs-password=$OBFS_PASSWORD#Hysteria2

## Vless-Reality
vless://$UUID@$SERVER_IP:$VL_PORT/?type=tcp&encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=$REALITY_PUBLIC_KEY&sid=$SHORT_ID#Vless-Reality
EOF
    
    # 设置节点文件权限（包含认证凭证，必须 600）
    chmod 600 "$INSTALL_DIR/nodes.txt"
    log_info "节点信息已保存: $INSTALL_DIR/nodes.txt"
}

# ==================== 创建 systemd 服务 ====================
create_service() {
    log_step "创建 systemd 服务..."
    
    cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box proxy service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/sing-box run -c $INSTALL_DIR/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sing-box >/dev/null 2>&1
    log_info "systemd 服务已创建"
}

# ==================== 启动服务 ====================
start_service() {
    log_step "启动 sing-box 服务..."
    
    systemctl start sing-box
    
    sleep 2
    
    if systemctl is-active --quiet sing-box; then
        log_info "sing-box 服务运行正常"
    else
        log_error "sing-box 服务启动失败"
        journalctl -u sing-box --no-pager -n 20
        exit 1
    fi
}

# ==================== 配置防火墙 ====================
setup_firewall() {
    log_step "配置防火墙..."
    
    # firewalld
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$HY_PORT"/udp >/dev/null 2>&1
        firewall-cmd --permanent --add-port="$VL_PORT"/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        log_info "firewalld 规则已添加"
    fi
    
    # ufw
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$HY_PORT"/udp >/dev/null 2>&1
        ufw allow "$VL_PORT"/tcp >/dev/null 2>&1
        log_info "ufw 规则已添加"
    fi
    
    # iptables (fallback)
    if ! command -v firewall-cmd >/dev/null 2>&1 && ! command -v ufw >/dev/null 2>&1; then
        iptables -I INPUT -p udp --dport "$HY_PORT" -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport "$VL_PORT" -j ACCEPT 2>/dev/null || true
        log_info "iptables 规则已添加"
    fi
}

# ==================== 显示结果 ====================
show_result() {
    local SERVER_IP="$1"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${GREEN}  部署完成！${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${BLUE}服务器 IP:${NC} $SERVER_IP"
    echo ""
    
    cat "$INSTALL_DIR/nodes.txt"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${GREEN}  管理命令${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  启动: systemctl start sing-box"
    echo "  停止: systemctl stop sing-box"
    echo "  重启: systemctl restart sing-box"
    echo "  状态: systemctl status sing-box"
    echo "  日志: journalctl -u sing-box -f"
    echo "  节点: cat $INSTALL_DIR/nodes.txt"
    echo ""
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  自研 VPS 代理服务端部署脚本 v1.0"
    echo "  协议: Vless-Reality + Hysteria2"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # 检查 root 权限
    if [ "$(id -u)" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
    
    # 检测系统
    detect_system
    
    # 安装依赖
    install_deps
    
    # 获取公网 IP
    log_step "获取服务器 IP..."
    SERVER_IP=$(get_public_ip)
    if [ -z "$SERVER_IP" ]; then
        log_error "无法获取公网 IP"
        exit 1
    fi
    log_info "服务器 IP: $SERVER_IP"
    
    # BBR 优化
    install_bbr
    
    # 生成密钥
    generate_keys
    
    # 下载 sing-box
    download_singbox
    
    # 生成 Reality 密钥
    generate_reality_keys
    
    # 生成配置
    generate_config "$SERVER_IP"
    
    # 创建服务
    create_service
    
    # 配置防火墙
    setup_firewall
    
    # 启动服务
    start_service
    
    # 显示结果
    show_result "$SERVER_IP"
}

# 运行
main "$@"
