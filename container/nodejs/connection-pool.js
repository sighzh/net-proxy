/**
 * px 连接池管理器
 * 功能: 连接复用、故障转移、负载均衡
 * 版本: v2.0
 */

const net = require('net');
const EventEmitter = require('events');

// ==================== 配置 ====================
const POOL_CONFIG = {
    maxConnections: 100,           // 最大连接数
    minConnections: 5,             // 最小空闲连接数
    idleTimeout: 60000,            // 空闲超时 60秒
    connectionTimeout: 10000,      // 连接超时 10秒
    acquireTimeout: 5000,          // 获取连接超时 5秒
    retryAttempts: 3,              // 重试次数
    retryDelay: 1000,              // 重试延迟
    healthCheckInterval: 30000,    // 健康检查间隔
    enableLoadBalancing: true,     // 启用负载均衡
    failoverEnabled: true          // 启用故障转移
};

// ==================== 连接状态 ====================
const ConnectionState = {
    IDLE: 'idle',
    ACTIVE: 'active',
    PENDING: 'pending',
    CLOSED: 'closed',
    ERROR: 'error'
};

// ==================== 连接包装类 ====================
class ConnectionWrapper extends EventEmitter {
    constructor(socket, pool) {
        super();
        this.socket = socket;
        this.pool = pool;
        this.state = ConnectionState.IDLE;
        this.createdAt = Date.now();
        this.lastUsedAt = Date.now();
        this.requestCount = 0;
        this.errorCount = 0;
        
        this.setupHandlers();
    }
    
    setupHandlers() {
        this.socket.on('error', (err) => {
            this.errorCount++;
            this.state = ConnectionState.ERROR;
            this.emit('error', err);
        });
        
        this.socket.on('close', () => {
            this.state = ConnectionState.CLOSED;
            this.emit('close');
        });
    }
    
    acquire() {
        if (this.state !== ConnectionState.IDLE) {
            return false;
        }
        this.state = ConnectionState.ACTIVE;
        this.lastUsedAt = Date.now();
        this.requestCount++;
        return true;
    }
    
    release() {
        if (this.state === ConnectionState.ACTIVE) {
            this.state = ConnectionState.IDLE;
            this.lastUsedAt = Date.now();
            this.pool.emit('connectionReleased', this);
        }
    }
    
    close() {
        if (this.state !== ConnectionState.CLOSED) {
            this.state = ConnectionState.CLOSED;
            this.socket.destroy();
        }
    }
    
    isHealthy() {
        return this.state === ConnectionState.IDLE || this.state === ConnectionState.ACTIVE;
    }
    
    isIdle() {
        return this.state === ConnectionState.IDLE;
    }
    
    isExpired() {
        return Date.now() - this.lastUsedAt > POOL_CONFIG.idleTimeout;
    }
}

// ==================== 连接池类 ====================
class ConnectionPool extends EventEmitter {
    constructor(options = {}) {
        super();
        this.config = { ...POOL_CONFIG, ...options };
        this.pools = new Map();  // host:port -> connection pool
        this.stats = {
            totalCreated: 0,
            totalAcquired: 0,
            totalReleased: 0,
            totalErrors: 0,
            totalTimeouts: 0
        };
        
        // 启动健康检查
        this.startHealthCheck();
        
        // 启动空闲连接清理
        this.startIdleCleanup();
    }
    
    /**
     * 获取或创建连接池
     */
    getPoolKey(host, port) {
        return `${host}:${port}`;
    }
    
    /**
     * 创建新连接
     */
    async createConnection(host, port) {
        return new Promise((resolve, reject) => {
            const socket = net.connect({
                host,
                port,
                timeout: this.config.connectionTimeout
            });
            
            const timeoutId = setTimeout(() => {
                socket.destroy();
                this.stats.totalTimeouts++;
                reject(new Error('Connection timeout'));
            }, this.config.connectionTimeout);
            
            socket.on('connect', () => {
                clearTimeout(timeoutId);
                const conn = new ConnectionWrapper(socket, this);
                this.stats.totalCreated++;
                resolve(conn);
            });
            
            socket.on('error', (err) => {
                clearTimeout(timeoutId);
                this.stats.totalErrors++;
                reject(err);
            });
        });
    }
    
    /**
     * 获取连接（带重试和故障转移）
     */
    async acquire(host, port, options = {}) {
        const poolKey = this.getPoolKey(host, port);
        const maxRetries = options.retryAttempts || this.config.retryAttempts;
        
        let lastError = null;
        
        for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                // 尝试从池中获取空闲连接
                if (this.pools.has(poolKey)) {
                    const pool = this.pools.get(poolKey);
                    const idleConn = pool.find(c => c.isIdle());
                    if (idleConn && idleConn.acquire()) {
                        this.stats.totalAcquired++;
                        return idleConn;
                    }
                }
                
                // 创建新连接
                const conn = await this.createConnection(host, port);
                
                if (!this.pools.has(poolKey)) {
                    this.pools.set(poolKey, []);
                }
                
                const pool = this.pools.get(poolKey);
                
                // 检查连接数限制
                if (pool.length >= this.config.maxConnections) {
                    // 移除最旧的空闲连接
                    const oldestIdle = pool.find(c => c.isIdle());
                    if (oldestIdle) {
                        oldestIdle.close();
                        pool.splice(pool.indexOf(oldestIdle), 1);
                    }
                }
                
                pool.push(conn);
                conn.acquire();
                this.stats.totalAcquired++;
                
                return conn;
                
            } catch (err) {
                lastError = err;
                console.log(`连接尝试 ${attempt}/${maxRetries} 失败: ${err.message}`);
                
                if (attempt < maxRetries) {
                    await new Promise(resolve => setTimeout(resolve, this.config.retryDelay));
                }
            }
        }
        
        // 故障转移：尝试备用地址
        if (this.config.failoverEnabled && options.failover) {
            console.log('尝试故障转移到备用地址...');
            for (const fallback of options.failover) {
                try {
                    return await this.acquire(fallback.host, fallback.port, { ...options, failover: null });
                } catch (err) {
                    console.log(`故障转移失败: ${err.message}`);
                }
            }
        }
        
        throw lastError || new Error('Failed to acquire connection');
    }
    
    /**
     * 释放连接
     */
    release(connection) {
        connection.release();
        this.stats.totalReleased++;
    }
    
    /**
     * 健康检查
     */
    startHealthCheck() {
        setInterval(() => {
            for (const [poolKey, pool] of this.pools) {
                const healthyCount = pool.filter(c => c.isHealthy()).length;
                const unhealthyCount = pool.filter(c => !c.isHealthy()).length;
                
                if (unhealthyCount > 0) {
                    console.log(`[健康检查] ${poolKey}: 健康=${healthyCount}, 不健康=${unhealthyCount}`);
                    
                    // 移除不健康的连接
                    for (let i = pool.length - 1; i >= 0; i--) {
                        if (!pool[i].isHealthy()) {
                            pool[i].close();
                            pool.splice(i, 1);
                        }
                    }
                }
            }
        }, this.config.healthCheckInterval);
    }
    
    /**
     * 清理空闲连接
     */
    startIdleCleanup() {
        setInterval(() => {
            for (const [poolKey, pool] of this.pools) {
                // 保留最小空闲连接数
                const idleConnections = pool.filter(c => c.isIdle());
                
                if (idleConnections.length > this.config.minConnections) {
                    // 按最后使用时间排序
                    idleConnections.sort((a, b) => a.lastUsedAt - b.lastUsedAt);
                    
                    // 移除过期的空闲连接
                    const toRemove = idleConnections
                        .slice(0, idleConnections.length - this.config.minConnections)
                        .filter(c => c.isExpired());
                    
                    for (const conn of toRemove) {
                        conn.close();
                        pool.splice(pool.indexOf(conn), 1);
                    }
                    
                    if (toRemove.length > 0) {
                        console.log(`[空闲清理] ${poolKey}: 移除了 ${toRemove.length} 个过期连接`);
                    }
                }
            }
        }, this.config.idleTimeout / 2);
    }
    
    /**
     * 获取统计信息
     */
    getStats() {
        const poolStats = {};
        for (const [key, pool] of this.pools) {
            poolStats[key] = {
                total: pool.length,
                idle: pool.filter(c => c.isIdle()).length,
                active: pool.filter(c => c.state === ConnectionState.ACTIVE).length,
                error: pool.filter(c => c.state === ConnectionState.ERROR).length
            };
        }
        
        return {
            ...this.stats,
            pools: poolStats
        };
    }
    
    /**
     * 关闭所有连接
     */
    async closeAll() {
        const closePromises = [];
        
        for (const [poolKey, pool] of this.pools) {
            for (const conn of pool) {
                closePromises.push(new Promise(resolve => {
                    conn.close();
                    resolve();
                }));
            }
        }
        
        await Promise.all(closePromises);
        this.pools.clear();
        console.log('所有连接已关闭');
    }
}

// ==================== 负载均衡器 ====================
class LoadBalancer {
    constructor() {
        this.backends = [];
        this.currentIndex = 0;
        this.healthStatus = new Map();
    }
    
    /**
     * 添加后端服务器
     */
    addBackend(host, port, weight = 1) {
        this.backends.push({ host, port, weight });
        this.healthStatus.set(`${host}:${port}`, true);
    }
    
    /**
     * 获取下一个可用的后端（轮询）
     */
    getNext() {
        const healthyBackends = this.backends.filter(b => 
            this.healthStatus.get(`${b.host}:${b.port}`)
        );
        
        if (healthyBackends.length === 0) {
            return null;
        }
        
        // 加权轮询
        const totalWeight = healthyBackends.reduce((sum, b) => sum + b.weight, 0);
        let random = Math.random() * totalWeight;
        
        for (const backend of healthyBackends) {
            random -= backend.weight;
            if (random <= 0) {
                return backend;
            }
        }
        
        return healthyBackends[0];
    }
    
    /**
     * 更新健康状态
     */
    updateHealth(host, port, isHealthy) {
        this.healthStatus.set(`${host}:${port}`, isHealthy);
    }
    
    /**
     * 获取健康后端数量
     */
    getHealthyCount() {
        return Array.from(this.healthStatus.values()).filter(v => v).length;
    }
}

// ==================== 导出 ====================
module.exports = {
    ConnectionPool,
    ConnectionWrapper,
    LoadBalancer,
    ConnectionState,
    POOL_CONFIG
};
