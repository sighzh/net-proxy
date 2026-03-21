#!/bin/bash
# ============================================================
# Argosbx Hysteria2 延迟优化配置脚本
# 版本: v2.0
# 针对: 洛杉矶等海外高延迟节点
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 配置目录
AGSBX_DIR="${HOME}/agsbx"
SB_JSON="${AGSBX_DIR}/sb.json"

# ==================== 检测服务器带宽 ====================
detect_bandwidth() {
    log_step "检测服务器带宽..."
    
    # 尝试使用 speedtest-cli
    if command -v speedtest-cli &>/dev/null; then
        log_info "使用 speedtest-cli 检测带宽..."
        local result=$(speedtest-cli --simple 2>/dev/null || echo "")
        if [[ -n "$result" ]]; then
            local download=$(echo "$result" | grep Download | awk '{print $2}')
            local upload=$(echo "$result" | grep Upload | awk '{print $2}')
            log_info "下载带宽: ${download} Mbps"
            log_info "上传带宽: ${upload} Mbps"
            echo "$upload"
            return
        fi
    fi
    
    # 尝试使用 fast.com API
    if command -v curl &>/dev/null; then
        log_info "请手动设置带宽，或使用以下命令检测:"
        log_info "  curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3"
    fi
    
    echo ""
}

# ==================== 优化 Hysteria2 配置 ====================
optimize_hysteria2_config() {
    local bandwidth_up="$1"
    local bandwidth_down="$2"
    
    log_step "优化 Hysteria2 配置..."
    
    if [[ ! -f "$SB_JSON" ]]; then
        log_warn "未找到 sing-box 配置文件: $SB_JSON"
        return 1
    fi
    
    # 备份原配置
    cp "$SB_JSON" "${SB_JSON}.bak"
    
    # 检查是否有 Hysteria2
    if ! grep -q '"type": "hysteria2"' "$SB_JSON"; then
        log_warn "配置中未找到 Hysteria2"
        return 1
    fi
    
    # 创建优化配置
    local tmp_json=$(mktemp)
    
    # 使用 Python 或 jq 进行 JSON 处理
    if command -v python3 &>/dev/null; then
        python3 << EOF
import json
import sys

with open('$SB_JSON', 'r') as f:
    config = json.load(f)

# 找到 Hysteria2 inbound 并优化
for inbound in config.get('inbounds', []):
    if inbound.get('type') == 'hysteria2':
        # 设置服务端带宽（如果提供）
        if '$bandwidth_up' and '$bandwidth_down':
            inbound['up_mbps'] = int('$bandwidth_up')
            inbound['down_mbps'] = int('$bandwidth_down')
            # 当服务端设置带宽时，建议忽略客户端带宽设置
            inbound['ignore_client_bandwidth'] = True
        else:
            # 没有设置带宽时，让客户端控制
            inbound['ignore_client_bandwidth'] = False
        
        print(f"Hysteria2 配置已优化:")
        print(f"  - ignore_client_bandwidth: {inbound.get('ignore_client_bandwidth', False)}")
        if 'up_mbps' in inbound:
            print(f"  - up_mbps: {inbound['up_mbps']}")
        if 'down_mbps' in inbound:
            print(f"  - down_mbps: {inbound['down_mbps']}")

with open('$SB_JSON', 'w') as f:
    json.dump(config, f, indent=4)

print("配置已保存")
EOF
        log_info "Hysteria2 配置优化完成"
    else
        log_warn "需要 python3 来优化 JSON 配置"
    fi
}

# ==================== 生成客户端配置建议 ====================
generate_client_config() {
    local server_ip="$1"
    local port="$2"
    local password="$3"
    
    log_step "生成客户端配置建议..."
    
    cat << EOF

============================================
Hysteria2 客户端配置建议 (洛杉矶节点优化)
============================================

【方案一: 客户端控制带宽】
适合: 不确定服务器带宽时使用

hysteria2://${password}@${server_ip}:${port}?security=tls&alpn=h3&insecure=1&sni=www.bing.com#LA-Hysteria2

客户端配置文件:
{
  "server": "${server_ip}:${port}",
  "auth": "${password}",
  "tls": {
    "sni": "www.bing.com",
    "insecure": true
  },
  "bandwidth": {
    "up": "50 Mbps",
    "down": "100 Mbps"
  },
  "fast_open": true,
  "lazy": true
}

【方案二: 服务端控制带宽】
适合: 已知服务器带宽时使用 (推荐)

服务端设置 ignore_client_bandwidth = true
并配置 up_mbps 和 down_mbps

【延迟优化建议】
1. 客户端 bandwidth 设置建议:
   - 下载: 实际带宽的 80-90%
   - 上传: 实际带宽的 80-90%

2. 开启 UDP 转发:
   - 客户端需开启 UDP 支持

3. 推荐客户端:
   - Windows: v2rayN, Nekoray
   - Android: Nekobox, v2rayNG
   - iOS: Shadowrocket, Stash

============================================
EOF
}

# ==================== 显示延迟对比 ====================
show_latency_comparison() {
    cat << EOF

============================================
洛杉矶节点协议延迟对比 (参考值)
============================================

协议类型          | 典型延迟 | 特点
-----------------|---------|------------------
Hysteria2 (UDP)  | +5-15ms | 最佳选择，QUIC协议
Tuic (UDP)       | +10-20ms| 次选，BBR拥塞控制
Vless-Reality    | +30-50ms| TCP协议，稳定
Vmess-WS         | +40-60ms| TCP协议，兼容性好

【推荐顺序】
1. Hysteria2 - 延迟最低，抗丢包
2. Tuic - 延迟较低，稳定
3. Vless-Reality - 延迟中等，安全

============================================
EOF
}

# ==================== 主函数 ====================
main() {
    echo ""
    echo "=========================================="
    echo "   Argosbx Hysteria2 延迟优化脚本"
    echo "   针对: 洛杉矶等海外高延迟节点"
    echo "=========================================="
    echo ""
    
    case "$1" in
        detect)
            detect_bandwidth
            ;;
        
        optimize)
            local up="${2:-}"
            local down="${3:-}"
            
            if [[ -z "$up" ]] || [[ -z "$down" ]]; then
                log_info "用法: $0 optimize <上传带宽Mbps> <下载带宽Mbps>"
                log_info "示例: $0 optimize 100 500"
                echo ""
                show_latency_comparison
                exit 1
            fi
            
            optimize_hysteria2_config "$up" "$down"
            ;;
        
        client)
            local server_ip=$(cat "${AGSBX_DIR}/server_ip.log" 2>/dev/null || echo "YOUR_SERVER_IP")
            local port=$(cat "${AGSBX_DIR}/hypt" 2>/dev/null || echo "PORT")
            local password=$(cat "${AGSBX_DIR}/uuid" 2>/dev/null || echo "PASSWORD")
            
            generate_client_config "$server_ip" "$port" "$password"
            ;;
        
        compare)
            show_latency_comparison
            ;;
        
        *)
            echo "用法: $0 {detect|optimize|client|compare}"
            echo ""
            echo "命令说明:"
            echo "  detect           - 检测服务器带宽"
            echo "  optimize <up> <down> - 优化 Hysteria2 配置"
            echo "                     示例: $0 optimize 100 500"
            echo "  client           - 生成客户端配置建议"
            echo "  compare          - 显示协议延迟对比"
            echo ""
            show_latency_comparison
            ;;
    esac
}

main "$@"
