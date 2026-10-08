# 腾讯CodeBuddy网关管家-Windows版

> [!TIP]
> **WorkBuddy Gateway Windows Suite** —— 让 [workbuddy-gateway](https://github.com/CangShui/workbuddy-gateway)
> 在 Windows 上**开机自启、一键安装、统一管理** 的 PowerShell 套件。

一套让 [workbuddy-gateway](https://github.com/CangShui/workbuddy-gateway) 在 Windows 上
**开机自启、一键安装、统一管理** 的 PowerShell 套件。

上游项目（Go 单二进制）负责网关本身；本仓库不复制、不修改上游代码，
只补齐 Windows 桌面场景缺失的部分：

| 能力 | 说明 |
| --- | --- |
| 一键安装 | 自动下载指定版本的官方二进制，校验 SHA256，写入 `%USERPROFILE%\workbuddy-gateway` |
| 登录自启 | 注册计划任务 `WorkBuddy Gateway`，用户登录后拉起网关；启动前先探测 `/v1/models` 防重复 |
| 统一管理 | `manage.ps1` 子命令：`status / start / stop / restart / logs / update / uninstall` |
| 健康检查 | `Test-GatewayHealth` 可独立复用；`status` 输出进程、任务、端口、HTTP 四层状态 |
| 安全默认 | 凭据文件永不入库；可选 API Key；默认仅监听 `127.0.0.1` |

## 快速开始

```powershell
# 1. 安装（默认最新 release，可选 -Version v1.13.16、-Port 8317）
.\scripts\install.ps1

# 2. 登录（扫码或浏览器验证，凭据写在安装目录，勿外传）
& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" login

# 3. 完成。重启后自动运行；或立即手动启动
.\scripts\manage.ps1 start
```

验证：浏览器打开 `http://127.0.0.1:8317/v1/models`，返回 `200` 即成功。

## 管理命令

```powershell
.\scripts\manage.ps1 status     # 任务 / 进程 / 端口 / HTTP 四层状态
.\scripts\manage.ps1 start      # 启动计划任务（等效开机自启路径）
.\scripts\manage.ps1 stop       # 停止任务并结束进程
.\scripts\manage.ps1 restart    # 先 stop 再 start
.\scripts\manage.ps1 logs       # 尾部查看今日网关日志（-Lines 200）
.\scripts\manage.ps1 update     # 下载并替换二进制后自动 restart
.\scripts\manage.ps1 uninstall  # 停止 + 删除任务 + 删除安装目录（-Force 跳过确认）
```

## 客户端接入（OpenAI 兼容）

| 设置 | 值 |
| --- | --- |
| 协议 | OpenAI Chat Completions 兼容（另有 Anthropic `/v1/messages` 入口） |
| Base URL | `http://127.0.0.1:8317/v1` |
| API Key | 默认不校验；在 `config.json` 开启 `apiKeyEnabled` 后填写 |
| 模型 | 以 `GET /v1/models` 实时返回为准 |

DSH / Cherry Studio / Chatbox 等客户端的逐步接入说明见
[docs/clients.zh-CN.md](docs/clients.zh-CN.md)。

## 目录结构

```text
scripts/install.ps1            一键安装（下载 + 校验 + 计划任务）
scripts/manage.ps1             日常管理入口
scripts/gateway-task.ps1       计划任务实际执行的自启脚本
scripts/common.ps1             共享函数库（路径 / 日志 / 健康检查）
docs/clients.zh-CN.md          客户端接入指南（DSH 等）
docs/troubleshooting.zh-CN.md  常见问题排查
```

## 安全须知

- `workbuddy.json` 是真实登录凭据，**切勿**提交仓库、粘贴聊天或上传网盘。
- 网关默认只监听回环地址；不要为远程访问直接改成 `0.0.0.0`，需要时用
  防火墙 + `config.json` 的 API Key 另行设计。
- 计划任务以当前用户身份运行，无需管理员权限。

## 相关链接

- 上游项目与完整功能说明：[CangShui/workbuddy-gateway](https://github.com/CangShui/workbuddy-gateway)
- 本套件问题反馈：[Issues](../../issues)

## License

[MIT](LICENSE)
