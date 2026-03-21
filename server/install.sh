#!/bin/sh
# ============================================================
# Argosbx 优化版一键脚本 v2.0
# 基于: yonggekkk/argosbx
# 新增: BBR优化 + 进程监控 + 心跳保活 + 健康检查
# 命令: px (proxy缩写，简单好记)
# ============================================================
export LANG=en_US.UTF-8

# ==================== 变量解析 ====================
[ -z "${vlpt+x}" ] || vlp=yes
[ -z "${vmpt+x}" ] || { vmp=yes; vmag=yes; }
[ -z "${vwpt+x}" ] || { vwp=yes; vmag=yes; }
[ -z "${hypt+x}" ] || hyp=yes
[ -z "${tupt+x}" ] || tup=yes
[ -z "${xhpt+x}" ] || xhp=yes
[ -z "${vxpt+x}" ] || vxp=yes
[ -z "${anpt+x}" ] || anp=yes
[ -z "${sspt+x}" ] || ssp=yes
[ -z "${arpt+x}" ] || arp=yes
[ -z "${sopt+x}" ] || sop=yes
[ -z "${warp+x}" ] || wap=yes
[ -z "${bbr+x}" ] || bbrenable=yes
[ -z "${watchdog+x}" ] || watchdogenable=yes

# 检查是否已运行
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'agsbx/(s|x)' || pgrep -f 'agsbx/(s|x)' >/dev/null 2>&1; then
if [ "$1" = "rep" ]; then
[ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || { echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！💣"; exit; }
fi
else
[ "$1" = "del" ] || [ "$1" = "opt" ] || [ "$1" = "bbr" ] || [ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || { echo "提示：未安装argosbx脚本，请在脚本前至少设置一个协议变量哦，再见！💣"; exit; }
fi

export uuid=${uuid:-''}
export port_vl_re=${vlpt:-''}
export port_vm_ws=${vmpt:-''}
export port_vw=${vwpt:-''}
export port_hy2=${hypt:-''}
export port_tu=${tupt:-''}
export port_xh=${xhpt:-''}
export port_vx=${vxpt:-''}
export port_an=${anpt:-''}
export port_ar=${arpt:-''}
export port_ss=${sspt:-''}
export port_so=${sopt:-''}
export ym_vl_re=${reym:-''}
export cdnym=${cdnym:-''}
export argo=${argo:-''}
export ARGO_DOMAIN=${agn:-''}
export ARGO_AUTH=${agk:-''}
export ippz=${ippz:-''}
export warp=${warp:-''}
export name=${name:-''}
export oap=${oap:-''}

v46url="https://icanhazip.com"
agsbxurl="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

# ==================== 显示帮助 ====================
showmode(){
echo "Argosbx优化版脚本 v2.0 - 一键SSH命令"
echo "---------------------------------------------------------"
echo "主脚本: bash <(curl -Ls https://your-domain/argosbx-opt.sh)"
echo ""
echo "【协议变量】(必选其一)"
echo "  hypt=\"\"    - Hysteria2 (推荐，延迟最低)"
echo "  tupt=\"\"    - Tuic (次选)"
echo "  vlpt=\"\"    - Vless-TCP-Reality"
echo "  vmpt=\"\"    - Vmess-WS"
echo "  vwpt=\"\"    - Vless-WS-ENC"
echo "  xhpt=\"\"    - Vless-XHTTP-Reality"
echo "  anpt=\"\"    - AnyTLS"
echo "  arpt=\"\"    - Any-Reality"
echo "  sspt=\"\"    - Shadowsocks-2022"
echo ""
echo "【优化变量】(可选)"
echo "  bbr=\"\"     - 启用BBR网络优化"
echo "  watchdog=\"\" - 启用进程监控"
echo ""
echo "【快捷命令】(安装后可用)"
echo "  px list    - 显示节点信息"
echo "  px rep     - 重置协议配置"
echo "  px res     - 重启服务"
echo "  px opt     - 仅安装网络优化"
echo "  px bbr     - 检查BBR状态"
echo "  px del     - 卸载脚本"
echo "---------------------------------------------------------"
echo
}

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Argosbx 优化版一键脚本 💣 v2.0"
echo "新增: BBR优化 + 进程监控 + 心跳保活 + 健康检查"
echo "命令: px (proxy缩写，简单好记)"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}')
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
[ -z "$(systemd-detect-virt 2>/dev/null)" ] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
arm64|aarch64) cpu=arm64;;
amd64|x86_64) cpu=amd64;;
*) echo "目前脚本不支持$(uname -m)架构" && exit
esac
mkdir -p "$HOME/agsbx"

# ==================== BBR 网络优化函数 ====================
install_bbr() {
echo
echo "=========启用BBR网络优化========="
echo "检测系统环境..."

# 检查内核版本
KERNEL_VER=$(uname -r | cut -d'-' -f1)
KERNEL_MAJOR=$(echo $KERNEL_VER | cut -d'.' -f1)
KERNEL_MINOR=$(echo $KERNEL_VER | cut -d'.' -f2)

if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
echo "警告: 内核版本过低 ($KERNEL_VER)，BBR需要 4.9+ 内核"
echo "建议升级内核后重新运行"
return 1
fi

# 检查当前拥塞控制
CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
echo "当前拥塞控制算法: $CURRENT_CC"

if [ "$CURRENT_CC" = "bbr" ]; then
echo "BBR 已启用，跳过安装"
return 0
fi

# 加载 BBR 模块
modprobe tcp_bbr 2>/dev/null || true
echo "tcp_bbr" > /etc/modules-load.d/tcp_bbr.conf 2>/dev/null || true

# 创建 sysctl 优化配置
cat > /etc/sysctl.d/99-argosbx-bbr.conf << 'EOF'
# BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP 缓冲区优化 (高延迟网络)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# UDP 缓冲区优化 (Hysteria2/Tuic)
net.core.netdev_max_backlog = 65536

# TCP 连接优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# 最大文件数
fs.file-max = 1048576
EOF

# 应用配置
sysctl -p /etc/sysctl.d/99-argosbx-bbr.conf > /dev/null 2>&1

# 验证
NEW_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [ "$NEW_CC" = "bbr" ]; then
echo "✅ BBR 启用成功！"
echo "   拥塞控制: $NEW_CC"
echo "   队列算法: $(sysctl -n net.core.default_qdisc)"
else
echo "❌ BBR 启用失败"
fi
}

check_bbr() {
echo
echo "=========BBR状态检查========="
echo "拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'unknown')"
echo "队列算法: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'unknown')"
echo "TCP读缓冲: $(sysctl -n net.ipv4.tcp_rmem 2>/dev/null | awk '{print $3/1024/1024 " MB"}')"
echo "TCP写缓冲: $(sysctl -n net.ipv4.tcp_wmem 2>/dev/null | awk '{print $3/1024/1024 " MB"}')"
echo "UDP读缓冲: $(sysctl -n net.core.rmem_max 2>/dev/null | awk '{print $1/1024/1024 " MB"}')"
}

# ==================== 进程监控函数 ====================
install_watchdog() {
echo
echo "=========启用进程监控========="

cat > "$HOME/agsbx/watchdog.sh" << 'WATCHDOG_EOF'
#!/bin/bash
# Argosbx 进程监控脚本
WATCHDOG_LOG="$HOME/agsbx/watchdog.log"
PID_DIR="$HOME/agsbx/pids"
mkdir -p "$PID_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$WATCHDOG_LOG"; }

check_process() {
    local name="$1"
    local pattern="$2"
    if pgrep -f "$pattern" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

restart_singbox() {
    if [ -f "$HOME/agsbx/sb.json" ] && [ -x "$HOME/agsbx/sing-box" ]; then
        pkill -f 'agsbx/sing-box' 2>/dev/null
        sleep 1
        nohup "$HOME/agsbx/sing-box" run -c "$HOME/agsbx/sb.json" >/dev/null 2>&1 &
        log "Sing-box 已重启"
    fi
}

restart_xray() {
    if [ -f "$HOME/agsbx/xr.json" ] && [ -x "$HOME/agsbx/xray" ]; then
        pkill -f 'agsbx/xray' 2>/dev/null
        sleep 1
        nohup "$HOME/agsbx/xray" run -c "$HOME/agsbx/xr.json" >/dev/null 2>&1 &
        log "Xray 已重启"
    fi
}

restart_argo() {
    if [ -x "$HOME/agsbx/cloudflared" ]; then
        pkill -f 'agsbx/cloudflared' 2>/dev/null
        sleep 1
        if [ -f "$HOME/agsbx/sbargotoken.log" ]; then
            local token=$(cat "$HOME/agsbx/sbargotoken.log")
            nohup "$HOME/agsbx/cloudflared" tunnel --no-autoupdate run --token "$token" >/dev/null 2>&1 &
        elif [ -f "$HOME/agsbx/argoport.log" ]; then
            local port=$(cat "$HOME/agsbx/argoport.log")
            nohup "$HOME/agsbx/cloudflared" tunnel --url "http://localhost:$port" --no-autoupdate > "$HOME/agsbx/argo.log" 2>&1 &
        fi
        log "Argo 已重启"
    fi
}

# 主监控循环
while true; do
    if ! check_process "singbox" "agsbx/sing-box"; then
        [ -f "$HOME/agsbx/sb.json" ] && restart_singbox
    fi
    if ! check_process "xray" "agsbx/xray"; then
        [ -f "$HOME/agsbx/xr.json" ] && restart_xray
    fi
    if ! check_process "argo" "agsbx/cloudflared"; then
        [ -x "$HOME/agsbx/cloudflared" ] && restart_argo
    fi
    sleep 30
done
WATCHDOG_EOF

chmod +x "$HOME/agsbx/watchdog.sh"

# 启动监控
if ! pgrep -f 'watchdog.sh' >/dev/null 2>&1; then
    nohup bash "$HOME/agsbx/watchdog.sh" >/dev/null 2>&1 &
    echo "✅ 进程监控已启动"
else
    echo "进程监控已在运行"
fi
}

# ==================== 安装命令别名 ====================
install_command() {
    # 创建 px 命令
    local CMD_PATH="$HOME/bin/px"
    mkdir -p "$HOME/bin"
    
    cat > "$CMD_PATH" << 'CMD_EOF'
#!/bin/bash
# px - proxy 命令别名
SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

case "$1" in
    list|rep|res|del|upx|ups)
        bash <(curl -Ls "$SCRIPT_URL" 2>/dev/null || wget -qO- "$SCRIPT_URL" 2>/dev/null) "$@"
        ;;
    opt)
        bash <(curl -Ls "$SCRIPT_URL" 2>/dev/null || wget -qO- "$SCRIPT_URL" 2>/dev/null) "opt"
        ;;
    bbr)
        sysctl net.ipv4.tcp_congestion_control
        sysctl net.core.default_qdisc
        ;;
    help|--help|-h)
        echo "px - 代理管理命令"
        echo ""
        echo "用法: px <命令>"
        echo ""
        echo "命令:"
        echo "  list  - 显示节点信息"
        echo "  rep   - 重置协议配置"
        echo "  res   - 重启服务"
        echo "  del   - 卸载"
        echo "  bbr   - 检查BBR状态"
        echo "  opt   - 安装网络优化"
        ;;
    *)
        bash <(curl -Ls "$SCRIPT_URL" 2>/dev/null || wget -qO- "$SCRIPT_URL" 2>/dev/null) "$@"
        ;;
esac
CMD_EOF
    
    chmod +x "$CMD_PATH"
    
    # 添加到 PATH
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
    
    echo "✅ 命令已安装: px"
}

# ==================== 处理快捷命令 ====================
if [ "$1" = "list" ] || [ "$1" = "rep" ] || [ "$1" = "res" ] || [ "$1" = "del" ] || [ "$1" = "upx" ] || [ "$1" = "ups" ]; then
# 调用原脚本处理
exec bash <(curl -Ls "$agsbxurl" 2>/dev/null || wget -qO- "$agsbxurl" 2>/dev/null) "$@"
fi

# 单独优化命令
if [ "$1" = "opt" ]; then
install_bbr
echo
echo "网络优化完成！"
exit 0
fi

if [ "$1" = "bbr" ]; then
check_bbr
exit 0
fi

# ==================== 主安装流程 ====================
if [ ! -f sbx_update ]; then
echo "执行脚本中，请稍后"
if command -v apk >/dev/null 2>&1; then
apk update >/dev/null 2>&1
apk add gcompat libc6-compat >/dev/null 2>&1
elif command -v apt >/dev/null 2>&1; then
apt update >/dev/null 2>&1 && apt install coreutils util-linux -y >/dev/null 2>&1
fi
touch sbx_update
fi

# ==================== 安装 BBR 优化 ====================
if [ "$bbrenable" = "yes" ]; then
install_bbr
fi

# ==================== 调用原脚本安装代理 ====================
echo
echo "=========安装代理服务========="
bash <(curl -Ls "$agsbxurl" 2>/dev/null || wget -qO- "$agsbxurl" 2>/dev/null)

# ==================== 安装进程监控 ====================
if [ "$watchdogenable" = "yes" ]; then
install_watchdog
fi

# ==================== 安装命令别名 ====================
install_command

# ==================== 安装完成提示 ====================
echo
echo "=========================================="
echo "   Argosbx 优化版安装完成！"
echo "=========================================="
echo
echo "【优化状态】"
echo "  BBR优化: $([ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] && echo '✅ 已启用' || echo '❌ 未启用')"
echo "  进程监控: $(pgrep -f 'watchdog.sh' >/dev/null 2>&1 && echo '✅ 运行中' || echo '❌ 未运行')"
echo
echo "【快捷命令】"
echo "  px list  - 显示节点信息"
echo "  px res   - 重启服务"
echo "  px bbr   - 检查BBR状态"
echo
echo "【洛杉矶节点建议】"
echo "  优先使用 Hysteria2 协议 (延迟最低)"
echo "  其次使用 Tuic 协议"
echo
