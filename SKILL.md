---
name: publish-image-search-to-github-pages
description: 把本機的「以圖找圖」圖片識別系統（TensorFlow.js 在瀏覽器辨識）改寫成純靜態網站，建立 GitHub repo 並發佈到 GitHub Pages，給使用者一個 https 網址（手機可拍照、語音查詢）。當使用者說「把圖片辨識系統放上 github」「發佈到網站」「給我網址」時使用。範本：`20260923\AI_23_將手機辨別圖片系統發佈到網站`（原本機版：`0923\5.圖片識別系統`）。
---

# 圖片識別系統 → GitHub Pages

適用環境：Windows 11、PowerShell 5.1，可能沒有 git / gh / Python / Node。

## 架構
```
GitHub repo (main)  ──GitHub Pages (branch, legacy)──►  https://<user>.github.io/<repo>/
  index.html  catalog.json  images.json  images/  lib/tf.min.js  model/
```
全部是靜態檔；辨識在瀏覽器做。https → 相機、麥克風可用。

## 步驟

### 1. 改成靜態網站
- 圖片搬到 `images/`；複製 `index.html`、`catalog.json`、`lib/`、`model/`、`Start-Server.ps1`、`start.bat`
- 新增 `tools\Build-Index.ps1`：列出 `images/` → `images.json`（`file`、`size`、`hash`=SHA256 前 12 碼），UTF-8 無 BOM 輸出；`ConvertTo-Json -InputObject @($list)` 避免單張時變成物件
- `index.html` 的 `init()`：`fetch('api/images')` 改成同時讀 `images.json` + `catalog.json` 自己合併；圖片網址 `images/<檔名>?v=<hash>`；快取 key 改用 hash 並升版（`emb:v2`）
- `Start-Server.ps1`：拿掉 `/api/images`，啟動時先跑 `Build-Index.ps1`（本機預覽跟正式站同一套）
- 加 `.nojekyll`、`.gitignore`（`*.pptx`）、`README.md`、`publish.bat`（Build-Index → `git add -A` → commit → push）

### 2. 本機驗證
`start.bat` 啟動 → headless Chrome 開 `http://localhost:8765/?selftest=1`，讀 `#selftestSummary`（做法見下方「驗證」）。

### 3. 安裝工具、登入
```powershell
winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements --scope user
winget install --id GitHub.cli -e --silent --accept-package-agreements --accept-source-agreements
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
```
登入要使用者自己做（瀏覽器授權），給**完整路徑**（使用者那個 shell 的 PATH 也還沒更新）：
`! & "C:\Program Files\GitHub CLI\gh.exe" auth login --hostname github.com --git-protocol https --web`

### 4. 建 repo、推送、開 Pages
```powershell
git init -b main; git config user.name <user>; git config user.email <email>; git config core.quotepath false
git add -A; git commit -m "Image search system as static GitHub Pages site"
gh auth setup-git
gh repo create <user>/<repo> --public --source . --remote origin --push
gh api -X POST repos/<user>/<repo>/pages -f "source[branch]=main" -f "source[path]=/"
gh api -X POST repos/<user>/<repo>/pages/builds          # 保險：手動觸發一次建置
# 輪詢 gh api repos/<user>/<repo>/pages/builds/latest --jq .status 直到 built
```
- 免費帳號的 Pages 要 **public** repo
- **不要放 `.github/workflows/`**：`gh auth login` 的 token 沒有 `workflow` scope，push 會被拒。真的要用 Actions → 先 `gh auth refresh -s workflow`

### 5. 正式站驗證
- `Invoke-WebRequest` 檢查 `index.html`、`images.json`、`model/model.json`、一張圖片都是 200
- headless Chrome（全新 user-data-dir）開 `https://<user>.github.io/<repo>/?selftest=1`，結果要跟本機一樣

### 驗證（headless Chrome + DevTools protocol）
```powershell
Start-Process chrome -ArgumentList '--headless=new','--remote-debugging-port=0',"--user-data-dir=$ud",'about:blank'
$port = (Get-Content "$ud\DevToolsActivePort")[0]
$arr = (Invoke-WebRequest "http://127.0.0.1:$port/json" -UseBasicParsing).Content | ConvertFrom-Json
$tab = @($arr | % { $_ } | ? { $_.type -eq 'page' })[0]
# ClientWebSocket 連 $tab.webSocketDebuggerUrl → Page.navigate → 輪詢 Runtime.evaluate
```
接收回應的迴圈**一定要有逾時**，WebSocket 沒連上時否則會無限迴圈。跑完用 CommandLine 含 `$ud` 找出 chrome 關掉。

## 常見錯誤對照
| 症狀 | 原因 | 解法 |
|---|---|---|
| `gh`/`git` not recognized（剛裝完） | shell 的 PATH 沒更新 | 重讀 PATH，或用完整路徑 |
| push 被拒：`without workflow scope` | token 沒有 workflow 權限 | 拿掉 workflow 檔（`--amend`），Pages 改從分支發佈 |
| Pages 網址 404「There isn't a GitHub Pages site here」 | 還沒建置（改設定後不會自動建） | `POST pages/builds`，等 `built` |
| 初始化失敗：讀不到 images.json | 沒跑 Build-Index 或沒 commit | `publish.bat` |
| 新圖片沒出現 | `images.json` 沒更新 | 用 `publish.bat`，不要只 `git push` |
| DevTools `/json` 找不到 page | PS 5.1 陣列沒展開 | `Invoke-WebRequest` + `ConvertFrom-Json` + `% { $_ }` |
