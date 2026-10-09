---
name: workbuddy-gateway
description: Install, start, and connect the local WorkBuddy (Tencent CodeBuddy) OpenAI-compatible gateway so DSH can use the account's model quota. Use when the user asks to set up WorkBuddy/CodeBuddy as a provider, fix gateway connection issues, or manage the local gateway service.
---

# WorkBuddy Gateway (Tencent CodeBuddy quota for DSH)

Local gateway at `http://127.0.0.1:8317/v1` (OpenAI-compatible) that relays
DSH model calls to the user's logged-in Tencent CodeBuddy / WorkBuddy account.

## Decide what to do

1. **Check current state first** (always safe, read-only):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin-dir>/scripts/manage.ps1" status
   ```

   Four layers: ScheduledTask / Process / Port 8317 / HTTP.

2. **All layers green** → the gateway is fine. If DSH still fails, the problem is
   DSH provider config (Base URL must be exactly `http://127.0.0.1:8317/v1`,
   model IDs must match `/v1/models` output exactly).

3. **Not installed** (status errors about missing scripts/exe) → run
   `<plugin-dir>/scripts/install.ps1`, then tell the user to run
   `& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" login`
   themselves — login is interactive (QR / browser) and must be done by the user.

4. **Task/Process down but installed** → `manage.ps1 start` (waits for health),
   `manage.ps1 restart` if stuck, `manage.ps1 logs -Lines 100` to diagnose.

5. **HTTP down but process up** → account token expired. Ask the user to run
   `& "$env:USERPROFILE\workbuddy-gateway\workbuddy-gateway.exe" login`
   interactively; never attempt to read or move `workbuddy.json` (real credentials).

## Wire DSH to the gateway

Provider settings to apply (OpenAI-compatible):

| Setting | Value |
| --- | --- |
| Base URL | `http://127.0.0.1:8317/v1` |
| API Key | anything (gateway does not check by default) |
| Model | copy exact IDs from `GET /v1/models` |

### Thinking effort (incl. Max mode) and 1M context

The gateway forwards `reasoning_effort` verbatim — upstream CodeBuddy honors
`low/medium/high/max`, where `max` IS the Web UI's "Max mode". DSH hides the
thinking selector and estimates a conservative context window unless the
provider's `models` entries declare them. When wiring DSH (or fixing "context
too small" / "no effort selector" complaints), add per-model metadata:

```yaml
llm-pi-ai:
  providers:
    workbuddy:
      api: openai-completions
      baseURL: http://127.0.0.1:8317/v1
      defaultContextWindow: 1000000
      defaultMaxTokens: 64000
      models:
        - id: glm-5.3-flash
          name: GLM-5.3 Flash
          contextWindow: 1000000
          reasoningEfforts:
            off:
            low: low
            high: high
            max: max      # Max mode
        - id: deepseek-v4-pro
          contextWindow: 1000000
          reasoningEfforts:
            off:
            high: high    # forced-thinking model: no off/low/medium
```

Level reference (from CodeBuddy's official model catalog):

- `glm-5.3-flash`, `glm-5.3-flashx`: `off/low/high/max`, 1M context
- `glm-5.3`, `glm-5.2`, `hy3`, `kimi-k3-2`, `kimi-k2.x`: `off/medium/high`, 192k–1M
- `deepseek-v4-pro`, `hy4-preview`: `off/high` (thinking forced on), 1M

`-x` suffix variants are the same price/tier as the base model; some account
tiers reject them upstream with `11102 model service not found` — prefer base
IDs. Verify end-to-end after config: same prompt with `reasoning_effort`
`low` vs `max` must show clearly different reasoning lengths.

## Rules

- Never read, copy, or print `workbuddy.json` — it holds real credentials.
- `status` and `logs` are read-only; prefer them before any start/stop action.
- `install.ps1` needs network; it downloads the official binary and verifies SHA256.
- `uninstall` deletes credentials — always confirm with the user first.
