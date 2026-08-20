# GitHub Copilot Hooks

## Linux / macOS Setup

### 1. Create a user-level hook for GitHub Copilot
Create a file called `cjk-token-reducer.json` in `~/.copilot/hooks`.

```shell
$ mkdir -p ~/.copilot/hooks
$ touch ~/.copilot/hooks/cjk-token-reducer.json
```

Copy and paste the following JSON into the file:

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

### 2. Create a shell script for the `userPromptSubmitted` hook
Create a shell script called `cjk-token-reducer.sh` in `~/.copilot/hooks/scripts`.

```shell
$ mkdir -p ~/.copilot/hooks/scripts
$ touch ~/.copilot/hooks/scripts/cjk-token-reducer.sh
$ chmod +x ~/.copilot/hooks/scripts/cjk-token-reducer.sh
```

Copy and paste the following contents into the shell script:

```shell
#!/bin/bash

PAYLOAD=$(cat)
PROMPT=$(echo "$PAYLOAD" | jq -r ".prompt")

MODIFIED_PROMPT=$(echo "$PROMPT" | cjk-token-reducer | jq -r ".prompt")
jq -n --arg mp "$MODIFIED_PROMPT" '{"modifiedPrompt": $mp}'
```

---

## Windows Setup (PowerShell)

### 1. Create hook configuration
Create `$HOME\.copilot\hooks\cjk-token-reducer.json`:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.copilot\hooks\scripts"
```

In `$HOME\.copilot\hooks\cjk-token-reducer.json`:
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

### 2. Create PowerShell hook script
In `$HOME\.copilot\hooks\scripts\cjk-token-reducer.ps1`:

```powershell
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$prompt = $payload.prompt
$reduced = $prompt | cjk-token-reducer | ConvertFrom-Json
[PSCustomObject]@{ modifiedPrompt = $reduced.prompt } | ConvertTo-Json -Compress
```

---

## Test the hook using GitHub Copilot
When you complete the above steps, you can test your GitHub Copilot by providing a Chinese, Japanese, or Korean prompt. Your prompt will be translated into an English prompt, and the translated version will be sent to your selected AI model.
