# cjk-token-reducer

[English](README.md) | [繁體中文](README.zh-TW.md)

在使用中日韓（CJK）語言時，為 Claude Code 降低 35-50% 的 Token 消耗。

## 問題背景
在表達相同語意內容時，中日韓（CJK）語言消耗的 Token 數量通常是英文的 **2 到 4 倍**。
這種差距會導致 API 成本大幅提高、對話歷史更快達到上下文上限（Context Window Exhaustion），並壓縮 RAG 與 Agent 工作流程的有效記憶空間。

| 語言 | 平均 Token 膨脹倍率 | 典型範圍 | 說明 |
|----------|-----------------|---------------|-------|
| 中文 (Chinese) | ~2.0-3.0x | 1.5-4.0x | 罕見字或生僻字可能會被拆解成 3-4 個 Token |
| 日文 (Japanese) | ~2.12x | 1.5-8.0x | 漢字與假名混用會增加分詞難度 |
| 韓文 (Korean) | ~2.36x | 2.0-3.0x | 黏著語（Agglutinative）特性加劇了分詞低效 |

*註：Token 倍率數據基於 BPE Tokenizer 分析。實際節省比例取決於文字複雜度與技術專有名詞密度。*

### 為什麼會這樣？
低效的分詞機制源自於 Byte-Pair Encoding (BPE) 分詞演算法與訓練資料分布：
1. **語料庫偏差（Vocabulary Bias）**：現代 Tokenizer 主要使用英文語料進行訓練，常見英文單字會被合併為單一 Token；而 CJK 字元在訓練資料中出現頻率較低，通常無法合併為「詞」，常被拆成單字甚至原始 Byte。
2. **UTF-8 Byte 退化（UTF-8 Byte Fallback）**：這是 Token 膨脹的主因。
   - 許多 LLM Tokenizer 是以 UTF-8 Byte 處理文字。
   - 1 個英文字母佔 1 個 Byte。
   - 1 個 CJK 漢字在 UTF-8 中通常佔 **3 個 Byte**。
   - 若 CJK 字元不在 Tokenizer 的詞表中，Byte 層級的 Tokenizer 會將其展開為多個 Token。
3. **缺乏天然分界（Lack of Delimiters）**：英文以空白鍵作為天然詞界，有助於 Tokenizer 識別可合併的單元；CJK 語言缺乏空白分界，迫使 Tokenizer 純粹依賴統計頻率。

**結論**：LLM API 計費與上下文長度是以 Token 計量，而非以語意計量。使用中文提問相當於支付了額外的「Token 稅」。

---

## 解決方案
`cjk-token-reducer` 在將您的 CJK 提示詞（Prompt）送給 Claude 之前，會先將其翻譯為英文。
英文是 LLM Tokenizer 的「母語」，因此翻譯過程本質上就像是一層語意壓縮。

### 核心功能
- **降低 35-50% 輸入 Token 消耗**（相當於有效上下文長度翻倍）
- **程式碼與路徑保護**：自動抽離程式碼區塊、檔案路徑與 URL，不送去翻譯
- **智慧辨識技術專有名詞**：自動辨識 camelCase、PascalCase、SCREAMING_SNAKE_CASE 等識別碼
- **macOS 專屬 NLP 支援**：使用 Apple NaturalLanguage 框架進行智慧命名實體辨識（NER）
- **本機快取機制**：使用嵌入式 Sled 資料庫快取翻譯，避免重複呼叫 API
- **免費 Google 翻譯 API**：開箱即用，無須申請 API Key
- **資料隱私**：僅發送純文字提示詞進行翻譯，程式碼本機保留
- **極低延遲**：每次翻譯僅增加 100-300ms 延遲（命中快取時 < 1ms）

### 權衡與限制
本工具採用「翻譯-計算-回翻」（Translate-Compute-Translate, TCT）模式，存在以下固有權衡：

| 評估面向 | 影響與建議 |
|--------|--------|
| **語意精準度** | 翻譯可能造成語意微幅位移。關鍵專有名詞建議使用 `[[名詞]]` 進行強制保護。 |
| **文化語境** | 高語境的 CJK 成語或特定修辭轉為英文時可能失去部分韻味。 |
| **額外延遲** | 增加了 1 次 API 請求（100-300ms），適合非同步與 Coding Agent，較不適合極端低延遲的即時聊天。 |
| **回翻自然度** | 若設定模型以中文回覆，生成的中文可能會帶有一點「翻譯腔」。 |

**何時不建議使用本工具**：
- 法律、醫療等對措辭精確度要求極高且不容失真的情境。
- 已針對 CJK 原生最佳化的模型（如 DeepSeek V3、Qwen 2.5 等，其本身 CJK Tokenizer 已相當高效）。

---

## 安裝指南

### 方式 1：下載預編譯執行檔（推薦）
您可以從 [GitHub Releases](https://github.com/jserv/cjk-token-reducer/releases) 下載對應作業系統的執行檔：

- **Windows (x86_64)**：`cjk-token-reducer-windows-x86_64.exe`
- **Linux (x86_64)**：`cjk-token-reducer-linux-x86_64`
- **macOS (Apple Silicon)**：`cjk-token-reducer-macos-aarch64`

#### 一鍵快速安裝與 Hook 配置：

**Windows (PowerShell)：**
```powershell
# 1. 下載 Windows 執行檔
Invoke-WebRequest -Uri "https://github.com/jserv/cjk-token-reducer/releases/download/nightly/cjk-token-reducer-windows-x86_64.exe" -OutFile "cjk-token-reducer.exe"

# 2. 執行安裝腳本（自動配置 PATH 與 Claude Code Hook）
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 install
```

**Linux / macOS (Bash)：**
```shell
# 1. 下載執行檔
curl -Lo cjk-token-reducer https://github.com/jserv/cjk-token-reducer/releases/download/nightly/cjk-token-reducer-linux-x86_64
chmod +x cjk-token-reducer

# 2. 執行安裝腳本
./scripts/deploy.sh install
```

---

### 方式 2：透過 Cargo 安裝
```shell
# Linux / Windows
cargo install --git https://github.com/jserv/cjk-token-reducer

# macOS (啟用 NLP 支援)
cargo install --git https://github.com/jserv/cjk-token-reducer --features macos-nlp
```

---

### 方式 3：從原始碼編譯
```shell
git clone https://github.com/jserv/cjk-token-reducer
cd cjk-token-reducer

# 編譯 Release 版本
cargo build --release

# Windows (PowerShell 安裝)
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 install

# Linux / macOS (Make 安裝)
make install
# 或使用: ./scripts/deploy.sh install
```

#### 解除安裝：
- Windows：`powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 uninstall`
- Linux / macOS：`make uninstall` 或 `./scripts/deploy.sh uninstall`

---

## 設定與整合

### 1. 配置 AI Coding Agent
目前已測試並支援以下工具，請參閱各工具設定指引：
- **Claude Code**：[hooks/claude.zh-TW.md](hooks/claude.zh-TW.md)
- **GitHub Copilot**：[hooks/copilot.zh-TW.md](hooks/copilot.zh-TW.md)

---

### 2. 自訂設定檔（選用）
您可以建立 `.cjk-token.json` 來調整行為。程式會依照以下順序搜尋設定檔：
1. 當前工作目錄：`./.cjk-token.json`
2. 使用者家目錄：`~/.cjk-token.json`
3. 系統設定目錄：
   - Linux: `~/.config/cjk-token-reducer/.cjk-token.json`
   - Windows: `%APPDATA%\cjk-token-reducer\.cjk-token.json`
   - macOS: `~/Library/Application Support/cjk-token-reducer/.cjk-token.json`

```json
{
  "outputLanguage": "en",
  "threshold": 0.1,
  "enableStats": true,
  "cache": {
    "enabled": true,
    "ttlDays": 30,
    "maxSizeMb": 10
  },
  "preserve": {
    "englishTerms": true,
    "useNlp": true
  }
}
```

#### 設定參數說明
| 參數 | 型態 | 預設值 | 說明 |
|--------|------|---------|-------------|
| `outputLanguage` | string | `"en"` | 期望 Claude 回覆的語言（`"en"`, `"zh"`, `"ja"`, `"ko"`）。 |
| `threshold` | number | `0.1` | 觸發翻譯的 CJK 字元比例門檻（0.1 代表 10%）。 |
| `enableStats` | boolean | `true` | 是否統計並記錄節省的 Token 數據。 |
| `cache.enabled` | boolean | `true` | 是否啟用本機翻譯快取。 |
| `cache.ttlDays` | number | `30` | 快取過期天數。 |
| `cache.maxSizeMb` | number | `10` | 快取資料庫最大空間限制（MB）。 |
| `preserve.englishTerms` | boolean | `true` | 自動保留 CJK 文本中的英文技術名詞（camelCase 等）。 |
| `preserve.useNlp` | boolean | `true` | 使用 macOS 機器學習 NER 辨識專有名詞（僅 macOS 有效）。 |

#### 資料儲存位置
| 作業系統 | 快取目錄 | 統計資料目錄 |
|----------|-----------------|---------------------|
| **Linux** | `~/.cache/cjk-token-reducer/` | `~/.config/cjk-token-reducer/` |
| **macOS** | `~/Library/Caches/cjk-token-reducer/` | `~/Library/Application Support/cjk-token-reducer/` |
| **Windows** | `%LOCALAPPDATA%\cjk-token-reducer\` | `%APPDATA%\cjk-token-reducer\` |

- `translations.db/`：Sled 嵌入式資料庫（快取）
- `stats.json`：Token 使用統計資訊

---

## 使用方式
安裝與配置完成後，和平常一樣使用 Claude Code 即可：

```shell
claude
❯ 重構這個函式
# 自動轉為英文: "Refactor this function"

❯ この関数をリファクタリングしてください
# 自動轉為英文: "Please refactor this function"

❯ 이 함수 리팩토링 해줘
# 自動轉為英文: "Refactor this function"
```

### CLI 常用指令
```shell
# 檢視累計節省的 Token 統計
cjk-token-reducer --stats

# 檢視快取使用狀況
cjk-token-reducer --cache-stats

# 清除本機翻譯快取
cjk-token-reducer --clear-cache

# 測試翻譯效果（Dry-run 預覽模式）
cjk-token-reducer --dry-run

# 單次翻譯跳過快取
cjk-token-reducer --no-cache
```

### 統計資訊輸出範例
```text
╔══════════════════════════════════════════════════════════╗
║           CJK Token Reducer Statistics                   ║
╠══════════════════════════════════════════════════════════╣
║  Total Translations:            150                      ║
║  Translation Tokens:           3200                      ║
║  Estimated Saved:              8500                      ║
╚══════════════════════════════════════════════════════════╝
```

---

## 隱私與安全性
- **翻譯服務**：本工具使用公開的 Google 翻譯 API，純文字 Prompt 會發送到 Google 伺服器。
- **程式碼安全**：程式碼區塊與檔案路徑會在**本機抽離保護**，不會發送到翻譯服務。
- **本機儲存**：除了本機的 Token 統計與翻譯快取外，本工具不會上傳任何使用者數據。

---

## 授權條款
`cjk-token-reducer` 採用寬鬆的 **MIT 授權條款**。詳細內容請參閱 [LICENSE](LICENSE) 檔案。

## 參考文獻
* Petrov et al. (2023): [Language Model Tokenizers Introduce Unfairness Between Languages](https://arxiv.org/abs/2305.15425)
* Ahia et al. (2023): [Do All Languages Cost the Same? Tokenization in the Era of Commercial Language Models](https://arxiv.org/abs/2305.13704)
* Yennie Jun: [All Languages Are NOT Created (Tokenized) Equal](https://www.artfish.ai/p/all-languages-are-not-created-tokenized)
