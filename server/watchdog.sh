#!/bin/bash
# Argosbx 进程监控和自动重启脚本
# 版本: v2.0
# 功能: 监控代理进程状态，自动重启崩溃的服务

# ==================== 配置参数 ====================
WATCHDOG_CONFIG="${HOME}/agsbx/watchdog.conf"
LOG_FILE="${HOME}/agsbx/watchdog.log"
PID_DIR="${HOME}/agsbx/pids"

# 默认配置
CHECK_INTERVAL=30        # 检查间隔（秒）
MAX_RESTART_COUNT=5      # 最大重启次数
RESTART_COOLDOWN=60      # 重启冷却时间（秒）
HEALTH_CHECK_TIMEOUT=10  # 健康检查超时（秒）

# 创建必要的目录
mkdir -p "${PID_DIR}"
mkdir -p "${HOME}/agsbx"

# 加载配置（如果存在）
if [[ -f "${WATCHDOG_CONFIG}" ]]; then
    source "${WATCHDOG_CONFIG}"
fi

# ==================== 日志函数 ====================
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# ==================== 进程检查函数 ====================
check_process() {
    local process_name="$1"
    local pid_file="${PID_DIR}/${process_name}.pid"
    
    if [[ -f "${pid_file}" ]]; then
        local pid=$(cat "${pid_file}")
        if kill -0 "${pid}" 2>/dev/null; then
            return 0  # 进程运行中
        else
            log_warn "${process_name} 进程 (PID: ${pid}) 已停止"
            rm -f "${pid_file}"
            return 1
        fi
    fi
    return 1
}

# ==================== 健康检查函数 ====================
health_check_http() {
    local port="$1"
    local url="http://localhost:${port}/health"
    
    if command -v curl &>/dev/null; then
        local response=$(curl -s -m "${HEALTH_CHECK_TIMEOUT}" "${url}" 2>/dev/null)
        if [[ $? -eq 0 ]] && echo "${response}" | grep -q '"status"'; then
            return 0
        fi
    elif command -v wget &>/dev/null; then
        local response=$(timeout "${HEALTH_CHECK_TIMEOUT}" wget -qO- "${url}" 2>/dev/null)
        if [[ $? -eq 0 ]] && echo "${response}" | grep -q '"status"'; then
            return 0
        fi
    fi
    return 1
}

health_check_port() {
    local port="$1"
    local host="localhost"
    
    if command -v nc &>/dev/null; then
        if timeout "${HEALTH_CHECK_TIMEOUT}" nc -z "${host}" "${port}" 2>/dev/null; then
            return 0
        fi
    elif command -v bash &>/dev/null; then
        if timeout "${HEALTH_CHECK_TIMEOUT}" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ==================== 重启计数器 ====================
declare -A restart_counts
declare -A last_restart_time

can_restart() {
    local process_name="$1"
    local current_time=$(date +%s)
    local last_restart="${last_restart_time[${process_name}]:-0}"
    local count="${restart_counts[${process_name}]:-0}"
    
    # 检查冷却时间
    if [[ $((current_time - last_restart)) -lt "${RESTART_COOLDOWN}" ]]; then
        return 1
    fi
    
    # 检查重启次数
    if [[ "${count}" -ge "${MAX_RESTART_COUNT}" ]]; then
        # 如果超过冷却时间的一半，重置计数器
        if [[ $((current_time - last_restart)) -gt $((RESTART_COOLDOWN * 2)) ]]; then
            restart_counts[${process_name}]=0
            return 0
        fi
        return 1
    fi
    
    return 0
}

record_restart() {
    local process_name="$1"
    restart_counts[${process_name}]=$((${restart_counts[${process_name}]:-0} + 1))
    last_restart_time[${process_name}]=$(date +%s)
}

# ==================== 服务重启函数 ====================
restart_singbox() {
    log_info "正在重启 Sing-box 服务..."
    
    # 停止旧进程
    pkill -f 'agsbx/sing-box' 2>/dev/null
    sleep 2
    
    # 启动新进程
    if [[ -f "${HOME}/agsbx/sb.json" ]] && [[ -x "${HOME}/agsbx/sing-box" ]]; then
        nohup "${HOME}/agsbx/sing-box" run -c "${HOME}/agsbx/sb.json" >/dev/null 2>&1 &
        local pid=$!
        echo "${pid}" > "${PID_DIR}/singbox.pid"
        log_info "Sing-box 已重启，PID: ${pid}"
        record_restart "singbox"
        return 0
    fi
    return 1
}

restart_xray() {
    log_info "正在重启 Xray 服务..."
    
    # 停止旧进程
    pkill -f 'agsbx/xray' 2>/dev/null
    sleep 2
    
    # 启动新进程
    if [[ -f "${HOME}/agsbx/xr.json" ]] && [[ -x "${HOME}/agsbx/xray" ]]; then
        nohup "${HOME}/agsbx/xray" run -c "${HOME}/agsbx/xr.json" >/dev/null 2>&1 &
        local pid=$!
        echo "${pid}" > "${PID_DIR}/xray.pid"
        log_info "Xray 已重启，PID: ${pid}"
        record_restart "xray"
        return 0
    fi
    return 1
}

restart_argo() {
    log_info "正在重启 Argo 隧道..."
    
    # 停止旧进程
    pkill -f 'agsbx/cloudflared' 2>/dev/null
    sleep 2
    
    # 检查是否有固定隧道配置
    if [[ -f "${HOME}/agsbx/sbargotoken.log" ]]; then
        local token=$(cat "${HOME}/agsbx/sbargotoken.log")
        nohup "${HOME}/agsbx/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${token}" >/dev/null 2>&1 &
    elif [[ -f "${HOME}/agsbx/argoport.log" ]]; then
        local port=$(cat "${HOME}/agsbx/argoport.log")
        nohup "${HOME}/agsbx/cloudflared" tunnel --url "http://localhost:${port}" --edge-ip-version auto --no-autoupdate --protocol http2 > "${HOME}/agsbx/argo.log" 2>&1 &
    fi
    
    local pid=$!
    echo "${pid}" > "${PID_DIR}/argo.pid"
    log_info "Argo 隧道已重启，PID: ${pid}"
    record_restart "argo"
    return 0
}

# ==================== 主监控循环 ====================
monitor_services() {
    log_info "启动进程监控服务..."
    log_info "检查间隔: ${CHECK_INTERVAL}秒, 最大重启次数: ${MAX_RESTART_COUNT}"
    
    while true; do
        # 检查 Sing-box
        if [[ -x "${HOME}/agsbx/sing-box" ]]; then
            if ! check_process "singbox"; then
                if can_restart "singbox"; then
                    restart_singbox
                else
                    log_warn "Sing-box 重启次数已达上限，跳过"
                fi
            fi
        fi
        
        # 检查 Xray
        if [[ -x "${HOME}/agsbx/xray" ]]; then
            if ! check_process "xray"; then
                if can_restart "xray"; then
                    restart_xray
                else
                    log_warn "Xray 重启次数已达上限，跳过"
                fi
            fi
        fi
        
        # 检查 Argo
        if [[ -x "${HOME}/agsbx/cloudflared" ]]; then
            if ! check_process "argo"; then
                if can_restart "argo"; then
                    restart_argo
                else
                    log_warn "Argo 重启次数已达上限，跳过"
                fi
            fi
        fi
        
        # 检查端口健康状态
        local http_port="${PORT:-3000}"
        if ! health_check_http "${http_port}"; then
            log_warn "HTTP 服务健康检查失败 (端口: ${http_port})"
        fi
        
        # 检查代理端口
        for port_file in "${HOME}/agsbx/"*pt; do
            if [[ -f "${port_file}" ]]; then
                local port=$(cat "${port_file}")
                if ! health_check_port "${port}"; then
                    log_warn "端口 ${port} 无响应 ($(basename "${port_file}"))"
                fi
            fi
        done
        
        sleep "${CHECK_INTERVAL}"
    done
}

# ==================== 信号处理 ====================
cleanup() {
    log_info "收到停止信号，正在退出..."
    rm -f "${PID_DIR}/watchdog.pid"
    exit 0
}

trap cleanup SIGTERM SIGINT

# ==================== 主入口 ====================
main() {
    case "$1" in
        start)
            # 检查是否已运行
            if [[ -f "${PID_DIR}/watchdog.pid" ]]; then
                local old_pid=$(cat "${PID_DIR}/watchdog.pid")
                if kill -0 "${old_pid}" 2>/dev/null; then
                    echo "Watchdog 已在运行 (PID: ${old_pid})"
                    exit 1
                fi
            fi
            
            # 后台运行
            nohup "$0" _run >> "${LOG_FILE}" 2>&1 &
            local pid=$!
            echo "${pid}" > "${PID_DIR}/watchdog.pid"
            echo "Watchdog 已启动 (PID: ${pid})"
            ;;
        
        stop)
            if [[ -f "${PID_DIR}/watchdog.pid" ]]; then
                local pid=$(cat "${PID_DIR}/watchdog.pid")
                kill "${pid}" 2>/dev/null
                rm -f "${PID_DIR}/watchdog.pid"
                echo "Watchdog 已停止"
            else
                echo "Watchdog 未运行"
            fi
            ;;
        
        status)
            if [[ -f "${PID_DIR}/watchdog.pid" ]]; then
                local pid=$(cat "${PID_DIR}/watchdog.pid")
                if kill -0 "${pid}" 2>/dev/null; then
                    echo "Watchdog 运行中 (PID: ${pid})"
                else
                    echo "Watchdog 已停止 (PID 文件存在但进程不存在)"
                fi
            else
                echo "Watchdog 未运行"
            fi
            
            # 显示服务状态
            echo ""
            echo "=== 服务状态 ==="
            for svc in singbox xray argo; do
                if check_process "${svc}"; then
                    echo "${svc}: 运行中"
                else
                    echo "${svc}: 已停止"
                fi
            done
            ;;
        
        restart)
            "$0" stop
            sleep 2
            "$0" start
            ;;
        
        _run)
            monitor_services
            ;;
        
        *)
            echo "用法: $0 {start|stop|status|restart}"
            echo ""
            echo "命令说明:"
            echo "  start   - 启动监控服务"
            echo "  stop    - 停止监控服务"
            echo "  status  - 查看状态"
            echo "  restart - 重启监控服务"
            exit 1
            ;;
    esac
}

main "$@"
