# GitHub Copilot Hooks 設定指南

## Linux / macOS 設定步驟

### 1. 建立 GitHub Copilot 的使用者層級 Hook 設定
在 `~/.copilot/hooks` 目錄下建立名為 `cjk-token-reducer.json` 的檔案：

```shell
$ mkdir -p ~/.copilot/hooks
$ touch ~/.copilot/hooks/cjk-token-reducer.json
```

將以下 JSON 內容貼入檔案中：

```json
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "~/.copilot/hooks/scripts/cjk-token-reducer.sh"
      }
    ]
  }
}
```

### 2. 建立 `userPromptSubmitted` Hook 的 Shell 腳本
在 `~/.copilot/hooks/scripts` 目錄下建立名為 `cjk-token-reducer.sh` 的腳本：

```shell
$ mkdir -p ~/.copilot/hooks/scripts
$ touch ~/.copilot/hooks/scripts/cjk-token-reducer.sh
$ chmod +x ~/.copilot/hooks/scripts/cjk-token-reducer.sh
```

將以下內容貼入 Shell 腳本中：

```shell
#!/bin/bash

PAYLOAD=$(cat)
PROMPT=$(echo "$PAYLOAD" | jq -r ".prompt")

MODIFIED_PROMPT=$(echo "$PROMPT" | cjk-token-reducer | jq -r ".prompt")
jq -n --arg mp "$MODIFIED_PROMPT" '{"modifiedPrompt": $mp}'
```

---

## Windows 設定步驟 (PowerShell)

### 1. 建立 Hook 設定檔
建立目錄與 `$HOME\.copilot\hooks\cjk-token-reducer.json`：

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.copilot\hooks\scripts"
```

在 `$HOME\.copilot\hooks\cjk-token-reducer.json` 寫入：
```json
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "powershell": "$HOME/.copilot/hooks/scripts/cjk-token-reducer.ps1"
      }
    ]
  }
}
```

### 2. 建立 PowerShell Hook 腳本
在 `$HOME\.copilot\hooks\scripts\cjk-token-reducer.ps1` 寫入：

```powershell
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$prompt = $payload.prompt
$reduced = $prompt | cjk-token-reducer | ConvertFrom-Json
[PSCustomObject]@{ modifiedPrompt = $reduced.prompt } | ConvertTo-Json -Compress
```

---

## 測試 GitHub Copilot Hook
完成上述設定後，您可以在 GitHub Copilot 中輸入中文、日文或韓文進行測試。您的 Prompt 會被自動轉為英文送出給指定的 AI 模型。
