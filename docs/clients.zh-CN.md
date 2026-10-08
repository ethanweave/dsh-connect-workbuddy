# 客户端接入指南

网关本机地址：`http://127.0.0.1:8317/v1`（Base URL 必须带 `/v1`）。

所有 OpenAI 兼容客户端接入方式相同：**协议选 OpenAI，Base URL 填本机地址，API Key 按需填写，模型 ID 从 `/v1/models` 实时获取**。

## 通用步骤

1. 确认网关已运行：浏览器打开 <http://127.0.0.1:8317/v1/models>，能返回 JSON 即可。
2. 获取模型列表：

   ```powershell
   (Invoke-RestMethod "http://127.0.0.1:8317/v1/models").data.id
   ```

3. 在客户端中按下表填写，模型 ID 必须**逐字符精确**粘贴。

| 设置 | 值 |
| --- | --- |
| API 协议 | OpenAI |
| Base URL | `http://127.0.0.1:8317/v1` |
| API Key | 默认不校验可随意填；若在 `config.json` 开启了 `apiKeyEnabled`，填对应 Key |
| 模型 | 如 `glm-5.3-flash`、`deepseek-v4-pro` 等，以第 2 步返回为准 |

## DSH（DeepSeek Harness）

1. 打开 DSH 设置 → 提供商（Provider）→ 新建。
2. 协议选择 **OpenAI Chat Completions 兼容**。
3. Base URL 填 `http://127.0.0.1:8317/v1`。
4. 模型 ID 填写第 2 步拿到的精确值。注意形近 ID 是不同模型，例如
   `glm-5.3-flash` 与 `glm-5.3-flashx`。
5. 保存后发起一次对话验证。模型目录能返回 200 不代表聊天一定成功；
   聊天报认证错误时先执行 `workbuddy-gateway.exe status` 检查账号状态。

## Cherry Studio

1. 设置 → 模型服务 → 添加，提供商类型选 **OpenAI**。
2. API 地址填 `http://127.0.0.1:8317`（Cherry Studio 会自动补 `/v1`）。
3. API Key 随意填（未开启校验时），点击「管理」可自动拉取模型列表。

## Chatbox

1. 设置 → 模型 → 自定义提供方。
2. API 域名填 `http://127.0.0.1:8317/v1`。
3. 模型名称手动添加（Chatbox 不会自动发现模型）。

## 常见接错点

- **Base URL 少了 `/v1`**：报 404 时先检查这一项。
- **模型 ID 手抄出错**：永远从 `/v1/models` 复制，不要手打。
- **客户端和网关不在同一台电脑**：安装脚本把网关装在用户本机，DSH 等客户端
  也在本机，`127.0.0.1` 天然互通，开箱即用。若你确实想让**其他设备**远程调用，
  属于进阶场景：需自行配置监听地址、防火墙与 API Key，不要暴露到不可信网络。
- **开启 API Key 后客户端没同步**：`config.json` 的 `apiKeyEnabled` 打开后，所有客户端必须带同一个 Key。
