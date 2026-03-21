const os = require('os');
const http = require('http');
const fs = require('fs');
const net = require('net');
const { exec, execSync } = require('child_process');

// ==================== 配置参数 ====================
const CONFIG = {
    // 心跳配置
    heartbeat: {
        interval: 30000,      // 心跳间隔 30秒
        timeout: 60000,       // 心跳超时 60秒
        maxMissed: 3          // 最大丢失心跳次数
    },
    // 连接配置
    connection: {
        timeout: 10000,       // 连接超时 10秒
        retryDelay: 1000,     // 重试延迟 1秒
        maxRetries: 3         // 最大重试次数
    },
    // 健康检查配置
    healthCheck: {
        enabled: true,
        path: '/health',
        interval: 60000       // 健康检查间隔 60秒
    },
    // 缓冲区配置
    buffer: {
        highWaterMark: 1024 * 1024  // 1MB 缓冲区
    }
};

function ensureModule(name) {
    try {
        require.resolve(name);
    } catch (e) {
        console.log(`Module '${name}' not found. Installing...`);
        execSync(`npm install ${name}`, { stdio: 'inherit' });
    }
}

const { WebSocket, createWebSocketStream } = require('ws');
const subtxt = `${process.env.HOME}/agsbx/jh.txt`;
const NAME = process.env.NAME || os.hostname();
const PORT = process.env.PORT || 3000;
const uuid = process.env.uuid || '79411d85-b0dc-4cd2-b46c-01789a18c650';
const DOMAIN = process.env.DOMAIN || 'YOUR.DOMAIN';
const vlessInfo = `vless://${uuid}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&fp=chrome&type=ws&host=${DOMAIN}&path=%2F#Vl-ws-tls-${NAME}`;
console.log(`vless-ws-tls节点分享: ${vlessInfo}`);

// ==================== 连接统计 ====================
const stats = {
    totalConnections: 0,
    activeConnections: 0,
    failedConnections: 0,
    reconnections: 0,
    startTime: Date.now()
};

// ==================== 健康检查服务 ====================
let healthStatus = {
    status: 'healthy',
    lastCheck: Date.now(),
    details: {}
};

function updateHealthStatus(component, status) {
    healthStatus.details[component] = {
        status: status,
        timestamp: Date.now()
    };
    
    // 检查整体健康状态
    const allHealthy = Object.values(healthStatus.details).every(d => d.status === 'healthy');
    healthStatus.status = allHealthy ? 'healthy' : 'degraded';
    healthStatus.lastCheck = Date.now();
}

// ==================== 心跳管理器 ====================
class HeartbeatManager {
    constructor(ws) {
        this.ws = ws;
        this.missedHeartbeats = 0;
        this.lastPong = Date.now();
        this.interval = null;
        this.timeout = null;
        
        this.start();
    }
    
    start() {
        // 设置心跳间隔
        this.interval = setInterval(() => {
            if (this.ws.readyState === WebSocket.OPEN) {
                // 检查是否超时
                if (Date.now() - this.lastPong > CONFIG.heartbeat.timeout) {
                    this.missedHeartbeats++;
                    console.log(`心跳超时，丢失次数: ${this.missedHeartbeats}`);
                    
                    if (this.missedHeartbeats >= CONFIG.heartbeat.maxMissed) {
                        console.log('心跳丢失次数过多，关闭连接');
                        this.stop();
                        this.ws.terminate();
                        return;
                    }
                }
                
                // 发送 ping
                try {
                    this.ws.ping();
                } catch (e) {
                    console.log('发送心跳失败:', e.message);
                }
            }
        }, CONFIG.heartbeat.interval);
        
        // 监听 pong
        this.ws.on('pong', () => {
            this.lastPong = Date.now();
            this.missedHeartbeats = 0;
        });
    }
    
    stop() {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
        if (this.timeout) {
            clearTimeout(this.timeout);
            this.timeout = null;
        }
    }
}

// ==================== 连接重试管理器 ====================
class ConnectionRetryManager {
    constructor(host, port, options = {}) {
        this.host = host;
        this.port = port;
        this.options = options;
        this.retryCount = 0;
        this.maxRetries = options.maxRetries || CONFIG.connection.maxRetries;
        this.retryDelay = options.retryDelay || CONFIG.connection.retryDelay;
    }
    
    async connect() {
        return new Promise((resolve, reject) => {
            const attemptConnect = (attempt) => {
                if (attempt > this.maxRetries) {
                    stats.failedConnections++;
                    updateHealthStatus('tcp_connection', 'unhealthy');
                    reject(new Error(`连接失败，已达到最大重试次数 ${this.maxRetries}`));
                    return;
                }
                
                const socket = net.connect({
                    host: this.host,
                    port: this.port,
                    timeout: CONFIG.connection.timeout
                });
                
                const timeoutId = setTimeout(() => {
                    socket.destroy();
                    console.log(`连接超时，第 ${attempt} 次重试...`);
                    stats.reconnections++;
                    setTimeout(() => attemptConnect(attempt + 1), this.retryDelay);
                }, CONFIG.connection.timeout);
                
                socket.on('connect', () => {
                    clearTimeout(timeoutId);
                    updateHealthStatus('tcp_connection', 'healthy');
                    resolve(socket);
                });
                
                socket.on('error', (err) => {
                    clearTimeout(timeoutId);
                    console.log(`连接错误: ${err.message}，第 ${attempt} 次重试...`);
                    stats.reconnections++;
                    setTimeout(() => attemptConnect(attempt + 1), this.retryDelay);
                });
            };
            
            attemptConnect(1);
        });
    }
}

// ==================== 启动脚本 ====================
fs.chmod("start.sh", 0o777, (err) => {
    if (err) {
        console.error(`start.sh empowerment failed: ${err}`);
        return;
    }
    console.log(`start.sh empowerment successful`);
    const child = exec('bash start.sh');
    child.stdout.on('data', (data) => console.log(data));
    child.stderr.on('data', (data) => console.error(data));
    child.on('close', (code) => {
        console.log(`child process exited with code ${code}`);
        console.clear();
        console.log(`App is running`);
    });
});

// ==================== HTTP 服务器 ====================
const server = http.createServer((req, res) => {
    const url = req.url;
    
    // 健康检查端点
    if (url === CONFIG.healthCheck.path) {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            status: healthStatus.status,
            uptime: Math.floor((Date.now() - stats.startTime) / 1000),
            connections: {
                total: stats.totalConnections,
                active: stats.activeConnections,
                failed: stats.failedConnections,
                reconnections: stats.reconnections
            },
            lastCheck: healthStatus.lastCheck,
            details: healthStatus.details
        }, null, 2));
        return;
    }
    
    // 统计端点
    if (url === '/stats') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            uptime: Math.floor((Date.now() - stats.startTime) / 1000),
            connections: stats,
            memory: process.memoryUsage(),
            config: CONFIG
        }, null, 2));
        return;
    }
    
    if (url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('🟢恭喜！Argosbx小钢炮脚本-nodejs版部署成功！\n\n查看节点信息路径：/你的uuid\n健康检查路径：/health\n统计信息路径：/stats');
        return;
    }

    if (url === `/${uuid}`) {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        if (fs.existsSync(subtxt)) {
            fs.readFile(subtxt, 'utf8', (err, data) => {
                if (err) {
                    console.error(err);
                    res.end(`${vlessInfo}`);
                } else {
                    res.end(`${vlessInfo}\n${data}`);
                }
            });
        } else {
            res.end(`${vlessInfo}`);
        }
        return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 Not Found');
});

server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    updateHealthStatus('http_server', 'healthy');
});

// ==================== WebSocket 服务器 ====================
const wss = new (require('ws').Server)({ 
    server,
    clientTracking: true,
    perMessageDeflate: false  // 禁用压缩以提高性能
});
const uuidkey = uuid.replace(/-/g, "");

wss.on('connection', ws => {
    stats.totalConnections++;
    stats.activeConnections++;
    
    // 初始化心跳管理器
    const heartbeatManager = new HeartbeatManager(ws);
    
    // 连接超时处理
    const connectionTimeout = setTimeout(() => {
        if (ws.readyState === WebSocket.OPEN) {
            console.log('连接超时，未收到有效数据');
            ws.terminate();
        }
    }, 30000);  // 30秒内必须收到有效数据
    
    ws.once('message', async msg => {
        clearTimeout(connectionTimeout);
        
        try {
            const [VERSION] = msg;
            const id = msg.slice(1, 17);
            if (!id.every((v, i) => v == parseInt(uuidkey.substr(i * 2, 2), 16))) {
                stats.activeConnections--;
                return;
            }
            
            let i = msg.slice(17, 18).readUInt8() + 19;
            const port = msg.slice(i, i += 2).readUInt16BE(0);
            const ATYP = msg.slice(i, i += 1).readUInt8();
            const host = ATYP == 1 ? msg.slice(i, i += 4).join('.') :
                (ATYP == 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) :
                    (ATYP == 3 ? msg.slice(i, i += 16)
                        .reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), [])
                        .map(b => b.readUInt16BE(0).toString(16)).join(':') : ''));
            
            ws.send(new Uint8Array([VERSION, 0]));
            
            // 使用重试管理器建立连接
            const retryManager = new ConnectionRetryManager(host, port);
            
            try {
                const socket = await retryManager.connect();
                const duplex = createWebSocketStream(ws, { highWaterMark: CONFIG.buffer.highWaterMark });
                
                socket.write(msg.slice(i));
                
                // 双向数据流处理
                duplex.on('error', (err) => {
                    console.log('WebSocket流错误:', err.message);
                    socket.destroy();
                }).pipe(socket).on('error', (err) => {
                    console.log('TCP连接错误:', err.message);
                    duplex.destroy();
                }).pipe(duplex);
                
                socket.on('close', () => {
                    duplex.destroy();
                });
                
                socket.on('error', (err) => {
                    console.log('Socket错误:', err.message);
                });
                
            } catch (err) {
                console.log('连接失败:', err.message);
                ws.close();
            }
            
        } catch (err) {
            console.log('消息处理错误:', err.message);
            ws.close();
        }
    });
    
    ws.on('error', (err) => {
        console.log('WebSocket错误:', err.message);
        heartbeatManager.stop();
    });
    
    ws.on('close', () => {
        stats.activeConnections--;
        heartbeatManager.stop();
    });
});

// ==================== 定期健康检查 ====================
if (CONFIG.healthCheck.enabled) {
    setInterval(() => {
        // 检查 WebSocket 服务器状态
        updateHealthStatus('ws_server', wss.clients.size >= 0 ? 'healthy' : 'unhealthy');
        
        // 检查内存使用
        const memUsage = process.memoryUsage();
        const memThreshold = 500 * 1024 * 1024; // 500MB
        updateHealthStatus('memory', memUsage.heapUsed < memThreshold ? 'healthy' : 'warning');
        
        // 输出统计信息
        console.log(`[健康检查] 活跃连接: ${stats.activeConnections}, 总连接: ${stats.totalConnections}, 重连: ${stats.reconnections}`);
        
    }, CONFIG.healthCheck.interval);
}

// ==================== 优雅关闭 ====================
process.on('SIGTERM', () => {
    console.log('收到 SIGTERM 信号，正在关闭...');
    
    // 关闭 HTTP 服务器
    server.close(() => {
        console.log('HTTP 服务器已关闭');
    });
    
    // 关闭所有 WebSocket 连接
    wss.clients.forEach(client => {
        client.close(1001, '服务器正在关闭');
    });
    
    wss.close(() => {
        console.log('WebSocket 服务器已关闭');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('收到 SIGINT 信号，正在关闭...');
    process.exit(0);
});

// ==================== 未捕获异常处理 ====================
process.on('uncaughtException', (err) => {
    console.error('未捕获的异常:', err);
    updateHealthStatus('process', 'error');
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('未处理的 Promise 拒绝:', reason);
});

console.log('代理服务已启动，优化版本 v2.0');
console.log('配置: 心跳间隔=' + CONFIG.heartbeat.interval + 'ms, 连接超时=' + CONFIG.connection.timeout + 'ms');
