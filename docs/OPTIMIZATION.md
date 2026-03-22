# px 优化版本说明

## 版本信息
- 原版本: V25.11.20
- 优化版本: V2.0
- 优化日期: 2026-03-15

## 优化概述

针对原版本代理不稳定的问题，进行了以下核心优化：

### 1. WebSocket 心跳机制

**问题**: 长时间空闲的 WebSocket 连接会被中间设备（如 NAT、防火墙）断开。

**解决方案**:
- 添加心跳间隔配置（默认 30 秒）
- 添加心跳超时检测（默认 60 秒）
- 最大丢失心跳次数限制（默认 3 次）
- 自动断开无响应的连接

```javascript
// 配置参数
heartbeat: {
    interval: 30000,      // 心跳间隔 30秒
    timeout: 60000,       // 心跳超时 60秒
    maxMissed: 3          // 最大丢失心跳次数
}
```

### 2. 连接重试机制

**问题**: 网络波动导致连接失败时没有自动重试。

**解决方案**:
- 自动重试连接（默认最多 3 次）
- 重试延迟配置（默认 1 秒）
- 连接超时设置（默认 10 秒）

```javascript
// 配置参数
connection: {
    timeout: 10000,       // 连接超时 10秒
    retryDelay: 1000,     // 重试延迟 1秒
    maxRetries: 3         // 最大重试次数
}
```

### 3. 健康检查机制

**问题**: 无法监控服务运行状态，故障无法及时发现。

**解决方案**:
- 新增 `/health` 健康检查端点
- 新增 `/stats` 统计信息端点
- 定期健康检查（默认 60 秒）
- 内存使用监控

**健康检查响应示例**:
```json
{
  "status": "healthy",
  "uptime": 3600,
  "connections": {
    "total": 100,
    "active": 10,
    "failed": 2,
    "reconnections": 5
  },
  "lastCheck": 1710500000000,
  "details": {
    "http_server": { "status": "healthy" },
    "ws_server": { "status": "healthy" },
    "tcp_connection": { "status": "healthy" },
    "memory": { "status": "healthy" }
  }
}
```

### 4. 进程监控与自动重启

**问题**: 服务进程崩溃后无法自动恢复。

**解决方案**:
- 创建 `watchdog.sh` 进程监控脚本
- 自动检测进程状态
- 自动重启崩溃的服务
- 重启次数限制和冷却时间
- 端口健康检查

**使用方法**:
```bash
# 启动监控
./watchdog.sh start

# 停止监控
./watchdog.sh stop

# 查看状态
./watchdog.sh status

# 重启监控
./watchdog.sh restart
```

### 5. 连接池管理

**问题**: 频繁创建/销毁连接导致性能下降。

**解决方案**:
- 创建 `connection-pool.js` 连接池管理器
- 连接复用
- 空闲连接清理
- 故障转移支持
- 负载均衡

**连接池特性**:
- 最大连接数限制（默认 100）
- 最小空闲连接数（默认 5）
- 空闲超时清理（默认 60 秒）
- 健康检查（默认 30 秒）

### 6. 错误处理增强

**问题**: 错误处理不完善，异常可能导致服务崩溃。

**解决方案**:
- 完善的错误捕获和处理
- 未捕获异常处理
- Promise 拒绝处理
- 优雅关闭支持

### 7. 统计与监控

**新增统计信息**:
- 总连接数
- 活跃连接数
- 失败连接数
- 重连次数
- 服务运行时间
- 内存使用情况

## 文件结构

```
px/
├── container/
│   └── nodejs/
│       ├── index.js           # 优化后的主服务文件
│       ├── connection-pool.js # 新增：连接池管理器
│       ├── watchdog.sh        # 新增：进程监控脚本
│       ├── start.sh           # 原启动脚本
│       └── package.json
├── README.md
└── OPTIMIZATION.md            # 本文档
```

## 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| PORT | 3000 | HTTP 服务端口 |
| uuid | (随机) | UUID 密码 |
| DOMAIN | YOUR.DOMAIN | 域名 |
| NAME | (主机名) | 节点名称 |

### 可调参数

在 `index.js` 中的 `CONFIG` 对象可以调整：

```javascript
const CONFIG = {
    heartbeat: {
        interval: 30000,      // 心跳间隔（毫秒）
        timeout: 60000,       // 心跳超时（毫秒）
        maxMissed: 3          // 最大丢失心跳次数
    },
    connection: {
        timeout: 10000,       // 连接超时（毫秒）
        retryDelay: 1000,     // 重试延迟（毫秒）
        maxRetries: 3         // 最大重试次数
    },
    healthCheck: {
        enabled: true,        // 是否启用健康检查
        path: '/health',      // 健康检查路径
        interval: 60000       // 检查间隔（毫秒）
    },
    buffer: {
        highWaterMark: 1048576 // 缓冲区大小（1MB）
    }
};
```

## 部署指南

### Docker 部署

```bash
# 构建镜像
docker build -t px-optimized ./container/nodejs

# 运行容器
docker run -d \
  --name px \
  -e PORT=3000 \
  -e uuid="your-uuid" \
  -p 3000:3000 \
  px-optimized
```

### 手动部署

```bash
# 安装依赖
cd container/nodejs
npm install

# 启动服务
node index.js

# 启动进程监控（另一个终端）
chmod +x watchdog.sh
./watchdog.sh start
```

## 监控与维护

### 健康检查

```bash
# 检查服务健康状态
curl http://localhost:3000/health

# 查看统计信息
curl http://localhost:3000/stats
```

### 日志查看

```bash
# 查看进程监控日志
tail -f ~/px/watchdog.log
```

### 故障排查

1. **连接频繁断开**
   - 检查心跳配置是否合适
   - 检查网络稳定性
   - 查看日志中的错误信息

2. **服务无响应**
   - 检查健康检查端点
   - 查看进程监控状态
   - 检查内存使用情况

3. **重连失败**
   - 检查重试配置
   - 检查目标服务器状态
   - 查看网络连接

## 性能优化建议

1. **调整缓冲区大小**: 根据网络条件调整 `highWaterMark`
2. **优化心跳间隔**: 网络稳定时可适当增加心跳间隔
3. **连接池配置**: 根据并发量调整连接池参数
4. **内存监控**: 设置合理的内存阈值告警

## 兼容性说明

- 完全兼容原版本的所有协议
- 支持原版本的所有环境变量
- 新增功能不影响原有功能使用

## 更新日志

### V2.0 (2026-03-15)
- 新增 WebSocket 心跳机制
- 新增连接重试机制
- 新增健康检查端点
- 新增进程监控脚本
- 新增连接池管理器
- 增强错误处理
- 新增统计监控功能
- 支持优雅关闭
