# LLM-WIKI-TO-AGENT-Template — 繁體中文總覽

> **這是什麼？** 一個 meta-template。讓你在一個 macOS 上,從零蓋出一套「Obsidian 知識庫 + Telegram 對話 Agent + GitHub 備份」的完整堆疊。所有架構決策都來自 Andrej Karpathy 於 2026 年 4 月 3 日發布的「LLM Wiki」gist。
>
> **你需要做的事:** clone 這個 repo,打開 Claude Code,跟它說「walk me through AGENT.md」。剩下的事它會問你 6 個問題、然後幫你蓋完。45-90 分鐘搞定。

---

## 作者

**馬驊 (Alex Ma)** — CC10 成員、[痛點科技 (PainPoint Tech)](https://www.painpoint-ai.com) 創辦人。

- 📮 Email: [alexma@painpoint-ai.com](mailto:alexma@painpoint-ai.com)
- 🌐 Web: [www.painpoint-ai.com](https://www.painpoint-ai.com)

這份 template 是從我每天在跑的真實私人部署 (3 個 Obsidian 知識庫 + 3 個 Hermes 對話 agent + 1 個 ops 編排骨幹) 中,把可重用的核心提取出來、公開釋出的最小可運行版本。如果你蓋出來、跑起來、有意見或建議,歡迎來信。

---

## 把它想成一座私人圖書館

理解整個架構最快的方式 — **不要想成「知識庫」,想成「圖書館」**。每個技術元件都對應一個真實世界的角色。

> 你每天早上經過你的私人圖書館。**圖書館員**(一個叫 `{{AGENT_NAME}}` 的 Telegram bot)站在櫃台。你丟一段語音、一篇文章、一個半成形的想法到收件箱 — 他微笑收下、確認收件、放上**新書推車**。當晚趁你睡覺,圖書館跑它的**編目班**:推車上的每一份資料被讀過、交叉引用、上到**書架**對應位置,**主目錄卡**也跟著更新。原件被放進**密封檔案室**(永久保存、不再修改)。隔天早上你進館,問圖書館員「上週重點是什麼?」,他直接帶你到對的書架 — 每個論點都附目錄卡引用。每週圖書館會做一次安靜的**健康檢查**:孤兒書、過期導覽、館藏單薄處。圖書館員甚至會給你一份「值得 google 一下的問題」跟「該買的新書」清單。這間圖書館從不積壓未處理事務 — 因為唯一的員工從不無聊。

這一段就是整個系統。下面是技術對應:

| 圖書館裡 | 在這個 repo 裡 | 在做什麼 |
|---|---|---|
| **讀者 / 學者**(你) | 人類 | 捐贈資料、提問、決定方向 |
| **圖書館員** | `agents/{{AGENT_NAME}}/` — Hermes Telegram bot | 招呼你、確認收件、絕不自己歸檔 |
| **櫃台收件箱** | Telegram 聊天視窗 | 捐贈進來的地方 |
| **新書推車** | `{{VAULT_NAME}}/raw/inbox/` | 新捐贈等待編目的地方,完全不動 |
| **密封檔案室** | `{{VAULT_NAME}}/raw/inbox/.processed/` | 原件永久保存、不再修改 |
| **書架(編目後)** | `{{VAULT_NAME}}/wiki/` | 結構化知識的家 — 實體、概念、綜合 |
| **每張目錄卡** | `wiki/entities/`、`wiki/concepts/` 等資料夾內的單一 `.md` | 每個真實世界的東西一張卡 |
| **主目錄卡盒** | `wiki/index.md` | 主索引 — 回答任何問題都先看這個 |
| **館員日誌** | `wiki/log.md` | 每次編目班、每次提問都追加一筆 |
| **館員訓練手冊** | `CLAUDE.md`(+ `AGENTS.md` 給 Codex 的 sibling)| schema — 歸檔規則、NEVER 規則、館員的工作說明 |
| **夜班維護組** | `_ops/` — launchd 排程的 shell scripts | 編目班、每週巡檢、夜間異地備份 |
| **異地防火備份** | `_ops/scripts/daily-backup.sh` → 私人 GitHub repos | 偏執鏡像,03:33 跑 |

### 四個圖書館工作流程(就是四個 ops)

| 圖書館流程 | 在這個 repo 裡 | 做什麼 |
|---|---|---|
| **編目班** | `ingest` | 推車上的一份資料被讀、分類、寫摘要、跨頁交叉引用。建立新目錄卡或更新既有的。原件移進密封檔案室。日誌追加一筆。 |
| **盤點** | `compile` | 你在 Obsidian 手動編了一堆東西之後,主目錄從現有書架重新生成。**只動目錄,不動書本內容**。 |
| **詢問櫃台** | `query` | 讀者提問。圖書館員讀主目錄、抽出相關書本、合成答案 — 每個論點都用目錄卡 `[[wikilink]]` 引用、選最適合的格式輸出(筆記、比較表、Marp 投影片、圖表、canvas),**然後把答案存回成一張新的目錄卡**,未來問題可以再引用它。 |
| **每週健康檢查** | `lint` | 巡書架。標記孤兒書、過期導覽、壞掉的交叉引用、frontmatter 不合規、決策該複審了。**也主動找方向**:建議該 google 哪些 topic、值得追問的 open question、反覆出現但還沒有專屬目錄卡的作者名。 |

LLM 改變了什麼:讓人放棄個人 wiki 的「bookkeeping」(維護交叉引用、保持摘要最新、追蹤矛盾、跨頁面一致性)— 剛好是 LLM 不會厭倦的事。**維護成本接近零;圖書館因此能複合**。

---

## 為什麼要這樣做 — 一頁理解 Karpathy 的核心觀點

大多數人用 LLM 處理文件的方式是 RAG: 上傳檔案、問問題、LLM 在查詢時從原文檢索。問題在 — **每一次問題,LLM 都從零開始**。沒有累積、沒有複合效應。

Karpathy 提出的 pattern 不一樣:讓 LLM **增量地、持續地維護一個 wiki**。新資料進來,LLM 不是「索引等下次用」,而是讀、理解、整合到既有結構裡 — 更新實體頁面、修正概念條目、標記矛盾、強化或挑戰既有的綜合分析。**知識編譯一次,然後持續維護**,而不是每次問答從頭推導。

核心差異:**wiki 是持續複合的資產**。交叉引用已經寫好、矛盾已經被標記、綜合分析已經反映了你讀過的一切。每多一筆資料、每多一個問題,wiki 都變得更豐富。

### 為什麼 LLM 改變了這件事

人類維護 wiki 失敗的不是「讀」或「想」,是 **bookkeeping** — 維護交叉引用、保持摘要最新、追蹤矛盾、保持頁面之間的一致性。維護成本長得比價值快,於是人放棄。

LLM 不會無聊、不會忘了更新交叉引用、一次能改 15 個檔案。**維護成本接近零**,wiki 因此能持續複合。

人的工作:挑來源、決定方向、問對問題、思考意義。
LLM 的工作:其他全部。

---

## 三層架構 (60 秒理解)

```
              ┌──────────────────────────────────────┐
  raw/        │ 原始來源文件 (immutable)              │
              │ 文章、語音逐字稿、剪貼網頁、PDF      │
              │ LLM 只讀,絕對不寫                   │
              └──────────────────────────────────────┘
                              │
                              ▼
              ┌──────────────────────────────────────┐
  wiki/       │ LLM 維護的結構化 markdown            │
              │ 實體頁、概念原子、決策、              │
              │ 來源摘要、index、log                 │
              │ 你讀,LLM 寫                         │
              └──────────────────────────────────────┘
                              ▲
                              │
              ┌──────────────────────────────────────┐
  CLAUDE.md   │ schema (Claude Code 啟動時自動載入)  │
  AGENTS.md   │ schema (Codex 啟動時自動載入,       │
              │ 內容是指回 CLAUDE.md 的 stub)        │
              │ 路由規則、frontmatter 約定、         │
              │ few-shot 範例、lint 規則              │
              │ LLM 的「工作說明書」                  │
              └──────────────────────────────────────┘
```

**四個操作循環** (ingest / compile / query / lint) 都在這個結構上跑。

---

## 四個操作 (你會用到的)

### 1. INGEST — 把新資料吃進 wiki
你丟一個新來源 (Telegram 訊息、剪貼的網頁、PDF) 進 `raw/inbox/`,LLM:
1. 讀這份原文
2. 跟你討論重點
3. 寫一份摘要頁進 `wiki/sources/`
4. 更新 index
5. 觸及到的 entity / concept 頁面跨 wiki 更新 (一份來源可能改 10-15 個檔案)
6. 在 log.md 追加一筆事件

### 2. COMPILE — 重建 index
當 wiki 形狀漂移 (你在 Obsidian 手動編輯了、批次匯入了一堆),index 過時。`compile` 從每個檔案的 frontmatter 重新生成 index.md。**只動 derived index,不動內容頁**。

### 3. QUERY — 對 wiki 提問
你問問題,LLM:
1. 先讀 `wiki/index.md`
2. 從 index 摘要挑出相關頁面
3. 讀那些頁面 (不是更多)
4. 合成答案,每個非顯而易見的論點都用 `[[wikilink]]` 引用
5. 選最適合的輸出格式 — markdown、比較表、Marp 投影片、matplotlib 圖、Obsidian canvas
6. **好答案會回存到 wiki 變成新頁面** — 你的探索因此跟著複合

### 4. LINT — 每週健康檢查
不只結構檢查 (孤兒頁、壞 wikilink、過期區域),還會 **主動找方向**:
- **WEBSEARCH SUGGESTED:** 哪些 topic 你的 wiki 涵蓋膚淺、一次精準 web search 可以補洞
- **OPEN QUESTION:** 哪些問題 wiki 「幾乎但還差一點」能回答 — 標出來給你下次 query
- **SOURCE GAP:** 哪些作者 / 作品 / 資料集在引用裡反覆出現但還沒有獨立 entity 頁

---

## 你會建出什麼 (端到端)

```
{{LOCAL_ROOT}}/
├── {{VAULT_NAME}}/             ← Obsidian 知識庫 (GitHub repo: {{VAULT_REPO}})
│   ├── CLAUDE.md               ← schema (最重要的檔案)
│   ├── AGENTS.md               ← Codex stub,指回 CLAUDE.md
│   ├── raw/                    ← inbox / 文章 / 逐字稿 / 資產
│   └── wiki/                   ← entities / concepts / sources / syntheses
│
├── agents/
│   └── {{AGENT_NAME}}/         ← Hermes Telegram bot (GitHub repo: {{AGENT_REPO}})
│       ├── SOUL.md             ← 對話人格 contract
│       ├── config.yaml         ← 模型路由 (ChatGPT via OpenAI Codex OAuth)
│       └── hooks/              ← Python hook 確定性寫檔
│
└── _ops/                       ← 排程骨幹 (GitHub repo: {{OPS_REPO}})
    ├── run-ingest.sh           ← Claude 分類 + ingest
    ├── run-lint.sh             ← 每週 lint
    ├── scripts/daily-backup.sh ← 偏執的夜間備份
    └── launchd/                ← 4 個排程 plist
```

**三個 GitHub repo、四個 launchd 排程任務、一條從 Telegram 到 wiki 的捕獲管線。**

---

## 安全與架構決策 (為什麼這樣設計)

### 1. 確定性 vs 生成式分流 (最重要的架構決策)
**必須發生的檔案寫入,放在 Python hook 或 shell script 裡,絕不放在 LLM tool call 裡。**

LLM 會幻覺、會拒絕、會 timeout。如果一封 Telegram 訊息能不能被存檔取決於 LLM 是否決定呼叫 write tool,**長期下你會丟掉 5-15% 的訊息**。

這個 template 的 pattern:
- **Hermes `agent:start` Python hook** 在 LLM 看到訊息之前,確定性地寫入 inbox 檔案
- **`run-ingest.sh`** 用 `claude -p` 做分類,然後 shell 自己 commit 跟 push
- **`daily-backup.sh`** 純 shell,完全沒有 LLM 介入

LLM 只負責「理解使用者、組好回覆」這個窄任務。

### 2. Anthropic TOS 分流
- **Claude (Haiku 4.5 + Sonnet 4.6)** 只在官方 `claude -p` CLI 跑,從 macOS keychain 抓 OAuth — 這是 Anthropic 明確允許的「first-party 使用」
- **ChatGPT (透過 OpenAI Codex OAuth)** 在 Hermes 對話 bot 裡跑,負責回覆 — OpenAI 允許這個用法
- **絕對不要** 把 Claude OAuth 放進 Hermes 或任何第三方 agent framework。Anthropic 2026 年 4 月起的 TOS 禁止。

### 3. 偏執備份
- **絕不** `git push --force`、`git reset --hard`、`git commit --amend`
- 每個 repo 都有原子 mkdir lockfile,防止並行 commit 衝突
- **Bulk-delete tripwire**: 一次 >20 個刪除就中止那個 repo,需要明確 override
- `git pull --rebase --autostash` 然後 push,衝突就 abort
- 排程時間刻意不用整點 (e.g. 03:33 而非 03:00),避開 GitHub API 雷雨群

---

## 怎麼開始 (4 個指令)

```bash
# 1. clone 這個 template 到你選的工作目錄
git clone https://github.com/AlexChanshuo/LLM-WIKI-TO-AGENT-Template.git \
    ~/Code/your-project/LLM-WIKI-TO-AGENT-Template
cd ~/Code/your-project/LLM-WIKI-TO-AGENT-Template

# 2. 在這個資料夾打開 Claude Code
claude

# 3. 跟 Claude 說:
#    walk me through AGENT.md — bootstrap the full stack

# 4. 回答 Claude 問的 6 個問題,剩下它會自己跑完
```

Claude 會問你:
1. 專案名稱 (短、小寫、用 hyphen) — `{{PROJECT_NAME}}`
2. 知識庫名稱 — `{{VAULT_NAME}}`
3. Agent 名稱 — `{{AGENT_NAME}}`
4. 你的 GitHub username — `{{GITHUB_USER}}`
5. Telegram bot handle (沒有可以說 "later") — `{{TELEGRAM_BOT_HANDLE}}`
6. 這個知識庫要記什麼的一句話描述 — `{{DOMAIN_DESCRIPTION}}`

回答完,Claude 會:替換掉所有 placeholder、scaffold 三個 repo、用 `gh` 建 GitHub repo、推初始 commit、生 launchd plist、跑第一次手動備份來驗證一切都對。

---

## 必要工具

| 需求 | 怎麼裝 | 為什麼 |
|---|---|---|
| macOS (Sonoma 或更新) | — | launchd 排程、keychain |
| GitHub 帳號 | https://github.com | 三個私人 repo |
| `gh` CLI | `brew install gh` | 建 repo + clone |
| Obsidian | https://obsidian.md | 知識庫 UI |
| Claude Code | https://claude.ai/download | 跑 template 的 LLM agent |
| Claude Code 訂閱 (Pro 以上) | — | OAuth token 給 `claude -p` |
| Hermes agent | https://hermes-agent.nousresearch.com | Telegram 對話 bot |
| Telegram 帳號 + bot token | https://t.me/BotFather | 捕獲管道 |
| `uv` Python 套件管理 | `brew install uv` | 隔離 venv |
| 1Password (或同類密碼庫) | — | 存 secrets 的標準位置 |

---

## 進階主題 (連結)

- **完整架構** — [`docs/01-architecture.md`](01-architecture.md)
- **vault 細節 + Obsidian plugin** — [`docs/02-vault-setup.md`](02-vault-setup.md)
- **Hermes agent 設定** — [`docs/03-hermes-agent.md`](03-hermes-agent.md)
- **備份安全** — [`docs/04-github-backup.md`](04-github-backup.md)
- **OAuth 分流 (TOS)** — [`docs/05-oauth-split.md`](05-oauth-split.md)
- **怎麼寫一份 AI 看得懂的 README** — [`docs/06-ai-onboarding-readme.md`](06-ai-onboarding-readme.md)
- **Karpathy 原文** — [`docs/research/sources/karpathy-2026-04-03-llm-wiki.md`](research/sources/karpathy-2026-04-03-llm-wiki.md)
- **三份社群延伸文章** — [`docs/research/sources/`](research/sources/)
- **AGENT.md 中文導讀** — [`../AGENT.zh-TW.md`](../AGENT.zh-TW.md)

---

## 常見問題

**Q: 我已經有 Obsidian vault,只想加 agent + 備份?**
A: 在 Claude Code 裡說「我已經有 vault,只 scaffold agent 跟 backup」。`AGENT.md` 有支援這個 path。

**Q: 我要兩個 vault (work / personal),不只一個?**
A: 跑 template 兩次,給不同 `{{PROJECT_NAME}}` 跟 `{{VAULT_NAME}}`。Karpathy 也建議至少分兩個 vault,不要全部丟一起。

**Q: 我不想用 Telegram,只想要 vault?**
A: 跟 Claude 說「先只 scaffold vault」。Agent 部分可以之後再加。

**Q: 我已經是 Codex 使用者,不是 Claude Code?**
A: 沒問題。Codex 開啟生成出來的 vault 時會自動讀 `AGENTS.md` (是個指回 `CLAUDE.md` 的 stub)。schema 只有一份,維護一份就好。

**Q: 規模能到多大?**
A: Karpathy 跟我們的實測,~100 個來源、~數百個頁面內,光靠 `index.md` 導航就夠,不需要 embedding RAG。超過這個規模,建議裝 [`qmd`](https://github.com/tobi/qmd) (本地 BM25 + vector + LLM rerank,CLI + MCP server) — 在 [`02-vault-setup.md`](02-vault-setup.md) 有設定步驟。

---

## 授權 / 致謝

這個 pattern 起源於 Andrej Karpathy 2026 年 4 月 3 日的「LLM Wiki」 gist。三層架構 (`raw/` + `wiki/` + schema)、四個操作循環 (ingest / compile / query / lint)、「孤兒頁啟發」(orphan heuristic) 全部來自他。

@hooeem (深度教學)、@defileo (指令食譜)、AI Edge (兩個 vault 框架) 三位把 Karpathy 的概念翻成可以實際 ship 的做法。本 template 是這四份原文的綜合實作。

從一個運行中的私人部署提取出來,公開釋出供任何人使用。**使用前自己 audit script**。
