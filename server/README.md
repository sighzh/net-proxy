# 服务端脚本

## 文件说明

| 文件 | 说明 |
|------|------|
| `install.sh` | 一键安装脚本（主入口） |
| `network-optimize.sh` | BBR + TCP/UDP 网络优化 |
| `watchdog.sh` | 进程监控自动重启 |

## 使用方法

```bash
# 一键安装（推荐）
hypt="" vlpt="" bbr="" watchdog="" bash install.sh

# 仅安装网络优化
bash network-optimize.sh install

# 查看BBR状态
bash network-optimize.sh status
```

## 变量说明

| 变量 | 说明 | 示例 |
|------|------|------|
| `hypt=""` | Hysteria2 协议 | `hypt=""` 或 `hypt="8443"` |
| `vlpt=""` | Vless-Reality 协议 | `vlpt=""` 或 `vlpt="443"` |
| `bbr=""` | 启用BBR优化 | `bbr=""` |
| `watchdog=""` | 启用进程监控 | `watchdog=""` |

## 安装后命令

```bash
px list    # 显示节点信息
px res     # 重启服务
px bbr     # 检查BBR状态
px del     # 卸载
```
