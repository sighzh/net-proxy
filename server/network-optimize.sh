#!/bin/bash
# ============================================================
# Argosbx 网络优化脚本 - BBR + TCP/UDP 内核参数优化
# 版本: v2.0
# 适用: 洛杉矶等海外高延迟节点
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 配置文件路径
SYSCTL_CONF="/etc/sysctl.d/99-argosbx-optimization.conf"
BACKUP_CONF="/etc/sysctl.d/99-argosbx-optimization.conf.bak"

# ==================== 检测系统信息 ====================
detect_system() {
    log_step "检测系统信息..."
    
    # 检测是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
    
    # 检测系统类型
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "系统: $PRETTY_NAME"
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    
    # 检测内核版本
    KERNEL_VER=$(uname -r | cut -d'-' -f1)
    KERNEL_MAJOR=$(echo $KERNEL_VER | cut -d'.' -f1)
    KERNEL_MINOR=$(echo $KERNEL_VER | cut -d'.' -f2)
    
    log_info "内核版本: $(uname -r)"
    
    # 检测虚拟化类型
    if command -v systemd-detect-virt &>/dev/null; then
        VIRT=$(systemd-detect-virt)
        if [[ "$VIRT" != "none" ]]; then
            log_info "虚拟化环境: $VIRT"
        else
            log_info "物理机环境"
        fi
    fi
    
    # 检测网络接口
    MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
    log_info "主网络接口: $MAIN_IF"
}

# ==================== 检查 BBR 支持 ====================
check_bbr_support() {
    log_step "检查 BBR 支持..."
    
    # 检查内核版本 (BBR 需要 4.9+)
    if [[ $KERNEL_MAJOR -lt 4 ]] || [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -lt 9 ]]; then
        log_warn "内核版本过低，BBR 需要 4.9+ 内核"
        log_info "当前内核: $KERNEL_VER"
        return 1
    fi
    
    # 检查 BBR 模块
    if modprobe -n --dry-run tcp_bbr &>/dev/null; then
        log_info "BBR 模块可用"
        return 0
    else
        log_warn "BBR 模块不可用，尝试编译..."
        return 1
    fi
}

# ==================== 获取当前拥塞控制算法 ====================
get_current_congestion_control() {
    current=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    echo $current
}

# ==================== 启用 BBR ====================
enable_bbr() {
    log_step "启用 BBR 拥塞控制..."
    
    # 检查当前状态
    CURRENT=$(get_current_congestion_control)
    log_info "当前拥塞控制算法: $CURRENT"
    
    if [[ "$CURRENT" == "bbr" ]]; then
        log_info "BBR 已启用"
        return 0
    fi
    
    # 加载 BBR 模块
    modprobe tcp_bbr 2>/dev/null || true
    
    # 设置 BBR
    echo "tcp_bbr" | tee /etc/modules-load.d/tcp_bbr.conf > /dev/null
    
    # 应用 BBR 设置
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    
    # 验证
    NEW=$(get_current_congestion_control)
    if [[ "$NEW" == "bbr" ]]; then
        log_info "BBR 启用成功！"
        return 0
    else
        log_error "BBR 启用失败"
        return 1
    fi
}

# ==================== TCP 参数优化 ====================
optimize_tcp() {
    log_step "优化 TCP 参数..."
    
    cat > "$SYSCTL_CONF" << 'EOF'
# ============================================================
# Argosbx 网络优化配置
# 针对: 洛杉矶等海外高延迟节点
# ============================================================

# ==================== BBR 拥塞控制 ====================
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ==================== TCP 缓冲区优化 ====================
# TCP 接收缓冲区 (针对高延迟大带宽)
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# ==================== TCP 连接优化 ====================
# TCP 内存分配 (页数)
net.ipv4.tcp_mem = 786432 1048576 1572864

# 最大打开文件数
fs.file-max = 1048576

# 最大 SYN 队列长度
net.ipv4.tcp_max_syn_backlog = 65536

# 最大连接跟踪
net.netfilter.nf_conntrack_max = 1048576

# TIME_WAIT 优化
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0

# FIN_TIMEOUT (秒)
net.ipv4.tcp_fin_timeout = 10

# Keep-alive 优化
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# ==================== TCP 性能优化 ====================
# 开启 TCP Fast Open
net.ipv4.tcp_fastopen = 3

# 开启 TCP SACK
net.ipv4.tcp_sack = 1

# 开启 TCP FACK
net.ipv4.tcp_fack = 1

# 开启时间戳
net.ipv4.tcp_timestamps = 1

# 开启窗口缩放
net.ipv4.tcp_window_scaling = 1

# MTU 探测
net.ipv4.tcp_mtu_probing = 1

# ==================== UDP 缓冲区优化 (Hysteria2/Tuic) ====================
# UDP 接收缓冲区
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 65536

# UDP 特定优化
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# ==================== 网络队列优化 ====================
# 网络设备积压队列
net.core.netdev_max_backlog = 65536

# SOMAXCONN
net.core.somaxconn = 65535

# ==================== 连接跟踪优化 ====================
# 连接跟踪超时
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30

# ==================== 安全优化 ====================
# SYN cookies (防 SYN 洪水)
net.ipv4.tcp_syncookies = 1

# SYN 重试次数
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2

# 忽略 ICMP 重定向
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# 忽略 ICMP ping
net.ipv4.icmp_echo_ignore_all = 0

# ==================== IPv6 优化 ====================
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF

    log_info "TCP 参数配置已保存到 $SYSCTL_CONF"
}

# ==================== 应用优化 ====================
apply_optimization() {
    log_step "应用网络优化..."
    
    # 备份原配置
    if [[ -f "$SYSCTL_CONF" ]]; then
        cp "$SYSCTL_CONF" "$BACKUP_CONF"
        log_info "已备份原配置到 $BACKUP_CONF"
    fi
    
    # 应用 sysctl 配置
    sysctl -p "$SYSCTL_CONF" > /dev/null 2>&1
    
    # 验证关键参数
    local bbr=$(sysctl -n net.ipv4.tcp_congestion_control)
    local qdisc=$(sysctl -n net.core.default_qdisc)
    local rmem=$(sysctl -n net.core.rmem_max)
    local wmem=$(sysctl -n net.core.wmem_max)
    
    log_info "拥塞控制: $bbr"
    log_info "队列算法: $qdisc"
    log_info "最大读缓冲: $((rmem/1024/1024)) MB"
    log_info "最大写缓冲: $((wmem/1024/1024)) MB"
}

# ==================== 优化系统限制 ====================
optimize_limits() {
    log_step "优化系统限制..."
    
    # 检查 limits.conf
    LIMITS_FILE="/etc/security/limits.conf"
    
    # 添加优化配置
    grep -q "argosbx-optimization" "$LIMITS_FILE" 2>/dev/null || {
        cat >> "$LIMITS_FILE" << 'EOF'

# argosbx-optimization: 增加文件描述符限制
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
EOF
        log_info "已优化系统限制"
    }
}

# ==================== 优化 Hysteria2 配置 ====================
optimize_hysteria2() {
    log_step "优化 Hysteria2 配置..."
    
    local sb_json="$HOME/agsbx/sb.json"
    
    if [[ -f "$sb_json" ]]; then
        # 检查是否有 Hysteria2 配置
        if grep -q '"type": "hysteria2"' "$sb_json"; then
            log_info "检测到 Hysteria2 配置"
            
            # 显示当前配置
            local ignore_bw=$(grep -A5 '"type": "hysteria2"' "$sb_json" | grep 'ignore_client_bandwidth' | head -1)
            log_info "当前 ignore_client_bandwidth: $ignore_bw"
            
            log_info "建议: 设置 ignore_client_bandwidth = true 并配置服务端带宽"
            log_info "示例: up='100 Mbps' down='100 Mbps' (根据服务器实际带宽调整)"
        fi
    fi
}

# ==================== 显示优化结果 ====================
show_results() {
    log_step "优化结果汇总"
    
    echo ""
    echo "=========================================="
    echo "        网络优化完成"
    echo "=========================================="
    echo ""
    
    # BBR 状态
    echo -e "${GREEN}[BBR 状态]${NC}"
    echo "  拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo "  队列算法: $(sysctl -n net.core.default_qdisc)"
    echo ""
    
    # TCP 缓冲区
    echo -e "${GREEN}[TCP 缓冲区]${NC}"
    echo "  读缓冲最大值: $(( $(sysctl -n net.ipv4.tcp_rmem | awk '{print $3}') / 1024 / 1024 )) MB"
    echo "  写缓冲最大值: $(( $(sysctl -n net.ipv4.tcp_wmem | awk '{print $3}') / 1024 / 1024 )) MB"
    echo ""
    
    # UDP 缓冲区
    echo -e "${GREEN}[UDP 缓冲区]${NC}"
    echo "  读缓冲最大值: $(( $(sysctl -n net.core.rmem_max) / 1024 / 1024 )) MB"
    echo "  写缓冲最大值: $(( $(sysctl -n net.core.wmem_max) / 1024 / 1024 )) MB"
    echo ""
    
    # 连接参数
    echo -e "${GREEN}[连接参数]${NC}"
    echo "  最大文件数: $(sysctl -n fs.file-max)"
    echo "  SYN 队列: $(sysctl -n net.ipv4.tcp_max_syn_backlog)"
    echo "  TIME_WAIT 复用: $(sysctl -n net.ipv4.tcp_tw_reuse)"
    echo ""
    
    # 建议
    echo -e "${YELLOW}[针对洛杉矶节点的建议]${NC}"
    echo "  1. 优先使用 Hysteria2 协议 (UDP/QUIC，低延迟)"
    echo "  2. 其次使用 Tuic 协议 (已配置 BBR)"
    echo "  3. TCP 协议建议使用 Reality 系列"
    echo "  4. 客户端建议开启 UDP 转发"
    echo ""
}

# ==================== 回滚功能 ====================
rollback() {
    log_step "回滚优化..."
    
    if [[ -f "$BACKUP_CONF" ]]; then
        mv "$BACKUP_CONF" "$SYSCTL_CONF"
        sysctl -p "$SYSCTL_CONF" > /dev/null 2>&1
        log_info "已回滚到原配置"
    else
        log_warn "没有找到备份配置"
    fi
}

# ==================== 主函数 ====================
main() {
    case "$1" in
        install|start|"")
            echo ""
            echo "=========================================="
            echo "   Argosbx 网络优化脚本 v2.0"
            echo "   针对: 洛杉矶等海外高延迟节点"
            echo "=========================================="
            echo ""
            
            detect_system
            check_bbr_support && enable_bbr
            optimize_tcp
            apply_optimization
            optimize_limits
            optimize_hysteria2
            show_results
            
            log_info "优化完成！配置已保存，重启后自动生效"
            ;;
        
        uninstall|stop)
            rollback
            log_info "已回滚优化配置"
            ;;
        
        status)
            echo ""
            echo "=========================================="
            echo "        当前网络优化状态"
            echo "=========================================="
            echo ""
            echo "BBR 状态: $(sysctl -n net.ipv4.tcp_congestion_control)"
            echo "队列算法: $(sysctl -n net.core.default_qdisc)"
            echo ""
            ;;
        
        *)
            echo "用法: $0 {install|uninstall|status}"
            echo ""
            echo "命令说明:"
            echo "  install   - 安装网络优化"
            echo "  uninstall - 卸载网络优化"
            echo "  status    - 查看优化状态"
            exit 1
            ;;
    esac
}

main "$@"
