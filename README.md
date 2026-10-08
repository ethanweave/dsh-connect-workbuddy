# 腾讯CodeBuddy网关管家-Windows版

> **一句话：让你在 DSH 里免费白嫖腾讯 CodeBuddy（WorkBuddy）的模型额度。**

[DSH（DeepSeek Harness）](https://github.com/ethanweave/dsh-desktop) 本身是一个 AI 编程前端，
它需要你配置一个模型提供商；而本项目的思路是：**用你自己的腾讯 CodeBuddy（WorkBuddy）账号额度
作为这个提供商** —— 账号里自带的每月额度 + 免费模型，从此在 DSH 里随便用，不花一分钱 API 费。

## 它是怎么工作的（3 步看懂）

```text
┌─────────┐      ┌──────────────────────┐      ┌─────────────────────┐
│   DSH   │ ───► │  本项目（本机网关）   │ ───► │ 腾讯 CodeBuddy 额度  │
│ 写代码   │      │  127.0.0.1:8317      │      │ （你自己的账号）     │
└─────────┘      └──────────────────────┘      └─────────────────────┘
```

1. **DSH 发起请求** → 发到本机 `127.0.0.1:8317`（OpenAI 兼容格式）
2. **本机网关中转** → 把请求翻译成 CodeBuddy 协议，用你已登录的账号调用上游
3. **额度扣在 CodeBuddy** → DSH 那边不需要任何 API Key / 充值 / 订阅

所以整个链路是：**DSH → 本项目网关 → CodeBuddy 额度 → 上游模型**，
你的 API 费用 = 0，消耗的是 CodeBuddy 账号本身的额度（含免费模型）。

> [!NOTE]
> 网关本体来自上游 [CangShui/workbuddy-gateway](https://github.com/CangShui/workbuddy-gateway)
> （Go 编写，单二进制）。本项目是它的 **Windows 增强套件**：一键安装、开机自启、统一管理，
> 让上面这条链路在 Windows 上开机即用、全程无感。

## 为什么需要本项目（而不是只装上游）

上游网关是个命令行程序，装完还要手动启动。本项目补齐 Windows 场景：

| 能力 | 说明 |
| --- | --- |
| 一键安装 | 自动下载官方二进制 + SHA256 校验，写入 `%USERPROFILE%\workbuddy-gateway` |
| 登录自启 | 注册计划任务 `WorkBuddy Gateway`，开机后自动拉起网关，防重复启动 |
| 统一管理 | `manage.ps1`：`status / start / stop / restart / logs / update / uninstall` |
| 健康检查 | 任务 / 进程 / 端口 / HTTP 四层状态一目了然 |
| 安全默认 | 凭据永不入库；默认仅监听 `127.0.0.1`；可选 API Key |

## 快速开始

**方式一：作为 DSH 插件安装（推荐）**

```powershell
dsh plugin add github:ethanweave/workbuddy-gateway-dsh
```

安装后直接对 Agent 说「帮我接入 WorkBuddy 网关」，它会按内置技能完成
安装、启动、排障，并指导你配置 DSH 提供商。

**方式二：直接使用脚本**

```powershell
# 1. 安装（自动下载官方二进制并校验）
.\scripts\install.ps1

# 2. 登录你的腾讯 CodeBuddy / WorkBuddy 账号（扫码或浏览器验证）
& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" login

# 3. 启动网关（之后开机自启，无需再管）
.\scripts\manage.ps1 start
```

然后在 **DSH → 设置 → 提供商** 里填：

| 设置 | 值 |
| --- | --- |
| 协议 | OpenAI 兼容 |
| Base URL | `http://127.0.0.1:8317/v1` |
| API Key | 随意填（网关默认不校验） |
| 模型 | 打开 <http://127.0.0.1:8317/v1/models> 复制任意 ID |

完成。在 DSH 里发起对话，模型响应来自你的 CodeBuddy 额度。

> Cherry Studio / Chatbox 等其他 OpenAI 兼容客户端同样适用，
> 详见 [docs/clients.zh-CN.md](docs/clients.zh-CN.md)。

## 管理命令

```powershell
.\scripts\manage.ps1 status     # 任务 / 进程 / 端口 / HTTP 四层状态
.\scripts\manage.ps1 start      # 启动计划任务（等效开机自启路径）
.\scripts\manage.ps1 stop       # 停止任务并结束进程
.\scripts\manage.ps1 restart    # 先 stop 再 start
.\scripts\manage.ps1 logs       # 查看网关日志（-Lines 200）
.\scripts\manage.ps1 update     # 升级二进制并自动重启
.\scripts\manage.ps1 uninstall  # 停止 + 删除任务 + 删除安装目录（-Force 跳过确认）
```

## 目录结构

```text
scripts/install.ps1            一键安装（下载 + 校验 + 计划任务）
scripts/manage.ps1             日常管理入口
scripts/gateway-task.ps1       计划任务实际执行的自启脚本
scripts/common.ps1             共享函数库（路径 / 日志 / 健康检查）
docs/clients.zh-CN.md          客户端接入指南（DSH / Cherry Studio / Chatbox）
docs/troubleshooting.zh-CN.md  常见问题排查
```

## 常见疑问

**Q：真的免费吗？**
A：消耗的是你腾讯 CodeBuddy / WorkBuddy 账号自带的额度（部分模型完全免费），
不产生任何新的 API 费用。额度用完或账号受限时，以账号实际状态为准。

**Q：需要管理员权限吗？**
A：不需要。计划任务以当前用户身份注册和运行。

**Q：要做网络配置吗？换个电脑还能用吗？**
A：不需要任何网络配置。网关和 DSH 都装在**用户自己的电脑**上，`127.0.0.1`
永远指向本机——不管你用的是哪台 Windows 设备，安装脚本跑一遍就开箱即用。
只有当你想让**别的设备**（手机 / 另一台电脑）也调用这台机器的网关时，
才涉及网络改造（见下方安全须知）。

**Q：聊天报认证错误？**
A：先跑 `workbuddy-gateway.exe status` 看账号状态，失效就重新 `login`，其余见
[docs/troubleshooting.zh-CN.md](docs/troubleshooting.zh-CN.md)。

## 安全须知

- `workbuddy.json` 是真实登录凭据，**切勿**提交仓库、粘贴聊天或上传网盘。
- 不要为远程访问直接把监听改成 `0.0.0.0`，需要时用防火墙 + API Key 另行设计。
- 请遵守上游服务条款；本项目不提供任何绕过额度限制的能力。

## 相关链接

- 上游网关与完整功能说明：[CangShui/workbuddy-gateway](https://github.com/CangShui/workbuddy-gateway)
- 本套件问题反馈：[Issues](../../issues)

## License

[MIT](LICENSE)
