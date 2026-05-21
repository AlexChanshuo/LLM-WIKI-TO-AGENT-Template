# AGENT.md — 中文導讀

> **這份檔案是給人類讀的。** 真正的 agent 劇本在英文版 [`AGENT.md`](./AGENT.md) — Claude Code / Codex 啟動時會自動讀英文版。如果你想知道「當我跟 Claude 說『walk me through AGENT.md』之後它在做什麼」,讀這份中文導讀。
>
> **作者:** 馬驊 (Alex Ma),CC10 成員,[痛點科技 (PainPoint Tech)](https://www.painpoint-ai.com) 創辦人。
> 聯絡: [alexma@painpoint-ai.com](mailto:alexma@painpoint-ai.com) · 網站: [www.painpoint-ai.com](https://www.painpoint-ai.com)

---

## AGENT.md 是什麼

是給 Claude Code 跑這個 template 用的 **劇本 (playbook)**。300 行,8 個步驟,13 條 NEVER 規則。

不是給人讀的設定文件,是給 AI agent 讀的工作說明。當你跟 Claude 說「walk me through AGENT.md」,Claude 就會按這份劇本走完整個 bootstrap 流程。

---

## 三個核心心智模型 (Claude 會用這三個觀點做決策)

### 1. Karpathy 三層架構

```
raw/  → LLM 只讀,絕不寫        (文章、語音、剪貼、PDF)
wiki/ ← LLM 寫,人讀             (entity、concept、synthesis)
CLAUDE.md   schema、職務描述     (路由、frontmatter、lint 規則)
```

四個循環跑在這個結構上:**ingest、compile、query、lint**。Agent 的每個 slash command、每個 launchd job 都對應到其中一個。

### 2. 確定性 vs 生成式分流 (最關鍵的決策)

**必須發生的檔案寫入,屬於 Python hook 或 shell script,不屬於 LLM tool call。** LLM 會幻覺、拒絕、timeout。長期下會丟 5-15% 的訊息。

- **Hermes `agent:start` Python hook** 在 LLM 看到訊息前,確定性地把 inbox 檔案寫入
- **`run-ingest.sh`** 用 `claude -p` 做分類,但 commit 跟 push 由 shell 自己處理
- **`daily-backup.sh`** 純 shell,沒有 LLM 介入

LLM 的工作很窄:理解使用者、組好回覆。

### 3. Anthropic TOS 分流

- **Claude (Haiku 4.5 + Sonnet 4.6)** 只在官方 `claude -p` CLI 跑,從 macOS keychain 抓 `CLAUDE_CODE_OAUTH_TOKEN`。這是 Anthropic 明確允許的 first-party 使用。
- **Claude 絕對不在 Hermes 或任何第三方 agent framework 跑。** 這是 Anthropic 2026 年 4 月起的 TOS 要求。
- **Hermes librarian 透過 OpenAI Codex OAuth 跑 ChatGPT** (你的 ChatGPT Pro 訂閱涵蓋)。OpenAI 允許這個用法。

**永遠不要** 在任何 Hermes `config.yaml` 加 `fallback_model: anthropic`。**永遠不要** 從 Hermes skill 裡 shell out 呼叫 `claude -p`。

---

## 8 個步驟摘要 (Claude 會跑這個流程)

### Step 1 — 問你 6 個問題

Claude 會用 **一個訊息** 問你:
1. 專案名稱 — `{{PROJECT_NAME}}`
2. vault 名稱 — `{{VAULT_NAME}}`
3. agent 名稱 — `{{AGENT_NAME}}`
4. GitHub username — `{{GITHUB_USER}}`
5. Telegram bot handle (可以說 "later") — `{{TELEGRAM_BOT_HANDLE}}`
6. 一句話描述這個知識庫的領域 — `{{DOMAIN_DESCRIPTION}}`

也會問本地根目錄 — `{{LOCAL_ROOT}}` (預設 `~/Documents/{{PROJECT_NAME}}`)。

回答完它會把推導出的其他值 (e.g. `{{OPS_REPO}} = {{PROJECT_NAME}}-ops`) 回給你看,等你說一聲 `yes` 才繼續。

### Step 2 — 替換 placeholder

Claude 用一個 shell 或 Python 一行 script 把所有 `{{UPPER_SNAKE}}` token 替換掉 (**不**用 LLM tool loop)。替換完跑 `grep -r '{{' {{LOCAL_ROOT}}/` 確認沒有殘留。

### Step 3 — Scaffold vault

1. `mkdir -p {{LOCAL_ROOT}}/{{VAULT_NAME}}`,複製 `templates/vault/` 進去
2. 把 `CLAUDE.md` 用你的 `{{DOMAIN_DESCRIPTION}}` 跟 starter routing table 填好 — 給你看 routing table、邀請你編輯
3. `git init -b main`,加 remote
4. `gh repo create {{GITHUB_USER}}/{{VAULT_REPO}} --private`
5. 初始 commit + push

### Step 4 — Scaffold agent

1. `mkdir -p {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}`,複製 `templates/agent/` 進去
2. 寫 `SOUL.md` — agent 的人格、語氣,從你的 domain 描述推導,寫好後給你確認
3. `.gitignore` 確認涵蓋 `.env`、`auth.json`、`sessions/`、`memories/`、`state.db` 等
4. 寫 `.env.example` 給空值,等你之後從 BotFather 跟 OpenAI 填入 `.env`
5. 寫 `config.yaml`,確認:
   - `model.default` = ChatGPT (`openai-codex` provider)
   - 沒有 `fallback_model: anthropic`
   - filesystem 範圍只限這個 vault
6. 驗證 `hooks/auto-save-inbox/handler.py` 指向正確的 vault 路徑
7. `git init`、建 repo、初始 commit、push

### Step 5 — Scaffold ops

1. `mkdir -p {{LOCAL_ROOT}}/_ops`,複製 `templates/ops/` 進去
2. 所有 `.sh` 加上執行權限
3. 確認 `run-ingest.sh` 從 keychain 拉 OAuth token
4. 確認 `daily-backup.sh`:per-repo lockfile、bulk-delete tripwire、pull-rebase-autostash、**沒有** `--force` / `--hard` / `--amend`
5. `git init`、建 repo、初始 commit、push

### Step 6 — 設定 launchd

1. 從 `templates/launchd/*.plist` 生 4 個 plist,把 `{{LAUNCHD_PREFIX}}` 跟絕對路徑替換掉
2. 挑非整點時間:`03:33` 備份、`08:17` + `20:43` ingest、週日 `09:17` lint。**絕對不要用整點。**
3. 軟連到 `~/Library/LaunchAgents/`
4. `launchctl load -w` 每個
5. `launchctl list | grep {{LAUNCHD_PREFIX}}` 驗證有 4 個 entries

### Step 7 — 第一次手動備份

不要等 03:33。手動跑一次抓出 scaffold 錯誤:

```bash
{{LOCAL_ROOT}}/_ops/scripts/daily-backup.sh
tail -n 50 {{LOCAL_ROOT}}/_ops/logs/daily-backup.log
```

預期看到三行 "push ok"。任一 repo 失敗就先 debug。

### Step 8 — 驗收

Smoke test checklist,跟你一起跑:

- [ ] 三個 GitHub repo 都看到初始 commit
- [ ] `launchctl list | grep {{LAUNCHD_PREFIX}}` 顯示 4 個 job
- [ ] 傳 "hi" 給 Telegram bot,30 秒內收到回覆
- [ ] 一個測試檔案出現在 `{{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/inbox/`
- [ ] 手動跑 `{{LOCAL_ROOT}}/_ops/run-ingest.sh {{VAULT_NAME}}` — Claude 分類跑、wiki 頁面建出來、git commit 推上去
- [ ] `tail -n 20` 看到 Step 7 的備份紀錄

六項都過,系統上線。Hand off。

---

## 13 條 NEVER 規則 (Claude 不會違反這些)

1. **絕不** `git push --force`。一次都不行。
2. **絕不** `git reset --hard` 任何時候。
3. **絕不** `git commit --amend`。每次備份都是全新 commit、有時間戳。
4. **絕不** 移除 bulk-delete tripwire。>20 個刪除自動 abort。
5. **絕不** 跳過 per-repo lockfile (原子 mkdir)。
6. **絕不** 把 Anthropic OAuth 放進 Hermes。
7. **絕不** 讓 LLM 決定要不要存 inbox 檔。Python hook 在 LLM 看到訊息前就寫入。
8. **絕不** commit secrets。`.env`、`auth.json` gitignored,canonical 副本放 1Password。
9. **絕不** 用整點排程 (e.g. 03:00、08:00、20:00)。用 03:33、08:17、20:43。
10. **絕不** 寫一份沒有「If you're an AI agent reading this」段落的 README。
11. **絕不** 在 Step 1 沒確認前就繼續往後走。
12. **絕不** 在任何 commit 進去的檔案用 emoji。
13. **絕不** 預設用非英文寫 customer-facing 輸出 — 除非明確被要求 (本中文導讀就是例外)。

---

## 你的角色 vs Claude 的角色

| 你決定 | Claude 執行 |
|---|---|
| 叫什麼名字 (project / vault / agent) | placeholder 替換、scaffold 三個 repo |
| 領域是什麼 | 第一次寫 routing table、給你看、邀請你編輯 |
| Telegram bot handle | 連 launchd、git、keychain 一次到位 |
| 任何不可逆操作的 yes / no | 強制守住 NEVER 規則,即使你想抄近路 |

**可逆 + 低成本的決策,Claude 自己做完告訴你**。
**不可逆的 (寫 secrets、push GitHub、load launchd plist),Claude 先停下來問你確認**。

---

## 完整英文劇本

[`AGENT.md`](./AGENT.md) — Claude 跑的實際劇本。本中文導讀是這份英文劇本的摘要。

兩份的對應:
- AGENT.md "Your role" ↔ 上方「你的角色 vs Claude 的角色」
- AGENT.md "Your mental model" ↔ 上方「三個核心心智模型」
- AGENT.md "Your step-by-step playbook" ↔ 上方「8 個步驟摘要」
- AGENT.md "Hard NEVER rules" ↔ 上方「13 條 NEVER 規則」
- AGENT.md "Where to look in this repo" ↔ 完整檔案地圖

如果有歧義,**以英文 AGENT.md 為準** — 那是 Claude 實際讀的版本。
