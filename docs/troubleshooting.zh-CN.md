# 常见问题排查

## 1. 客户端显示连接失败

按顺序检查：

```powershell
# ① 四层状态一览（任务 / 进程 / 端口 / HTTP）
.\scripts\manage.ps1 status

# ② HTTP 不通时看日志
.\scripts\manage.ps1 logs -Lines 100
```

| 现象 | 处理 |
| --- | --- |
| Task: Not registered | 重新运行 `scripts\install.ps1` 注册任务 |
| Task: Disabled | `Enable-ScheduledTask -TaskName 'WorkBuddy Gateway'` |
| Process: Not running | `.\scripts\manage.ps1 start` |
| Port: closed | 进程刚启动或启动失败，看日志 |
| HTTP: Unreachable | 进程在但接口不通，看日志确认上游账号状态 |

## 2. 模型目录能访问，但聊天报认证错误

目录接口可用 ≠ 上游聊天可用。在安装目录执行：

```powershell
& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" status
```

若显示授权失效，重新登录：

```powershell
& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" login
```

凭据热加载后即可恢复，无需重启网关。

## 3. 重启电脑后无法连接

计划任务在**用户登录时**触发。先登录 Windows，再执行 `manage.ps1 status`。
若任务显示 Ready/Running 但进程不在，查看 `logs\startup-task.log` 中的启动失败原因。

## 4. 升级后端口被旧进程占用

```powershell
.\scripts\manage.ps1 restart
```

若仍占用，手动确认没有第二个实例（任务已设 `IgnoreNew`，通常不会发生）：

```powershell
Get-Process workbuddy-gateway
```

## 5. 模型不存在或不可选

模型列表以上游为准，随时可能变化。永远从实时目录复制精确 ID：

```powershell
(Invoke-RestMethod "http://127.0.0.1:8317/v1/models").data.id
```

## 6. 想从其他设备访问本机网关

默认仅监听 `127.0.0.1`，这是刻意的安全默认。远程访问请自行评估：
防火墙规则 + 上游 `-addr` 参数 + `config.json` API Key 鉴权，
不要直接暴露到不可信网络。

## 7. 日志文件说明

| 文件 | 内容 |
| --- | --- |
| `logs\startup-task.log` | 自启脚本运行记录（谁启动了网关、健康检查结果） |
| `logs\gateway-YYYY-MM-DD.log` | 网关当天运行日志 |
| `logs\gateway-stdout.log` / `gateway-stderr.log` | 网关进程标准输出 / 错误 |
