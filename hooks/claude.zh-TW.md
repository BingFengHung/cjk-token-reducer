# Claude Code 設定指南

## 設定 Claude Code Hook
在您的 Claude Code 設定檔中加入以下內容：
- **Linux / macOS**：`~/.claude/settings.json`
- **Windows**：`%USERPROFILE%\.claude\settings.json`（例如 `C:\Users\<您的使用者名稱>\.claude\settings.json`）

此 Hook 會在您的 Prompt 正式送出給 Claude 前進行攔截與翻譯：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cjk-token-reducer"
          }
        ]
      }
    ]
  }
}
```

本工具會在標準輸入（stdin）接收 `{"prompt": "..."}` 格式的 JSON，並輸出修改後的 JSON 給 Claude Code。

---

## 運作流程圖
Hook 會在 `UserPromptSubmit` 事件點進行攔截，在 Claude 進行語意分析與工具呼叫前先完成 CJK 翻譯：

```
┌──────────────────────────────────────────────────────────────┐
│                     Claude Code 執行階段                      │
├──────────────────────────────────────────────────────────────┤
│  SessionStart ─────► 使用者輸入 Prompt (中文/日文/韓文)        │
│                           │                                  │
│                           ▼                                  │
│              ┌────────────────────────────┐                  │
│              │    UserPromptSubmit        │                  │
│              │  ┌──────────────────────┐  │                  │
│              │  │  cjk-token-reducer   │  │ ◄─ 攔截處理      │
│              │  │  - 偵測 CJK 比例      │  │                  │
│              │  │  - 查詢本機快取       │  │                  │
│              │  │  - 翻譯成英文         │  │                  │
│              │  │  - 保護程式碼與名詞   │  │                  │
│              │  └──────────────────────┘  │                  │
│              └────────────────────────────┘                  │
│                           │                                  │
│                           ▼                                  │
│                   Claude 接收 (英文 Prompt 進行思考)         │
│                           │                                  │
│                   ┌───────┴───────┐                          │
│                   ▼               ▼                          │
│              PreToolUse      (無工具呼叫)                    │
│                   │               │                          │
│                   ▼               │                          │
│              執行工具命令          │                          │
│                   │               │                          │
│                   ▼               │                          │
│              PostToolUse          │                          │
│                   │               │                          │
│                   └───────┬───────┘                          │
│                           ▼                                  │
│                        完成回覆                              │
└──────────────────────────────────────────────────────────────┘
```
