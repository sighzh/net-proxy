# 客户端脚本

## 文件说明

| 文件 | 说明 |
|------|------|
| `link-parser.sh` | 链接解析器（推荐使用） |
| `setup.sh` | 一键配置脚本 |
| `docker-compose.yml` | Docker Compose 配置 |
| `config.json` | sing-box 配置模板 |
| `gen-client-config.sh` | 配置生成器 |

## 使用方法

### 方法一：链接解析器（推荐）

```bash
# 运行解析器
bash link-parser.sh

# 粘贴服务端生成的链接
hysteria2://uuid@server:port?...
vless://uuid@server:port?...

# 自动生成配置并启动
```

### 方法二：手动配置

```bash
# 编辑配置
nano config.json
# 修改 YOUR_SERVER_IP, YOUR_UUID 等参数

# 启动
docker-compose up -d
```

## 代理地址

| 类型 | 地址 |
|------|------|
| HTTP | `http://127.0.0.1:7890` |
| SOCKS | `socks5://127.0.0.1:7891` |

## 控制命令

```bash
./proxy.sh start    # 启动
./proxy.sh stop     # 停止
./proxy.sh restart  # 重启
./proxy.sh test     # 测试连接
```

## 系统代理

```bash
# 开启
source env.sh on

# 关闭
source env.sh off
```
