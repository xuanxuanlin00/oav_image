# CLAUDE.md

本資料夾：**圖片識別（以圖找圖）系統**的 GitHub 版，發佈在 GitHub Pages（純靜態網站，辨識全在瀏覽器做）。
使用者可以用「上傳圖片」「相機拍照」「語音查詢」三種方式，找出圖庫中最相似的圖片。原始本機版在 `..\0923\5.圖片識別系統`。

- 網站：**https://xuanxuanlin00.github.io/oav_image/**（自我測試：`?selftest=1`）
- Repo：https://github.com/xuanxuanlin00/oav_image （public，分支 `main`）
- GitHub Pages 設定：`build_type=legacy`，從 `main` 分支根目錄發佈（不用 GitHub Actions）

## 檔案
- `index.html`：整個前端。啟動時讀 `images.json` + `catalog.json` 建立圖庫
- `images/`：圖庫圖片。檔名開頭代表類別：A 螺絲、B 狗、C 木工機械、D 鋸片、E 汽車（各 3 張）
- `images.json`：由 `tools\Build-Index.ps1` 產生，列出 `images/` 的檔名、大小、內容雜湊（SHA256 前 12 碼）。**要 commit**
- `catalog.json`：每張圖的 `name`、`category`、`keywords`，以及類別同義詞（語音/文字查詢用）
- `lib/tf.min.js`：TensorFlow.js 4.22.0；`model/`：MobileNet v2 feature-vector（約 8.4 MB）
- `publish.bat`：重建 `images.json` → `git add -A` → commit → push（一鍵發佈）
- `start.bat` / `Start-Server.ps1`：本機預覽 `http://localhost:8765/`（啟動時會先跑 `Build-Index.ps1`；只提供靜態檔）
- `.nojekyll`：叫 GitHub Pages 不要跑 Jekyll
- `*.pptx` 在 `.gitignore`，不上傳

## 新增圖片
圖片放進 `images/` → 在 `catalog.json` 加上名稱/類別/關鍵字（可省略，會顯示「未分類」）→ 雙擊 `publish.bat` → 約 1 分鐘後網站更新。
使用者瀏覽器的特徵快取 key 含內容雜湊，圖片換了會自動重算。

## 運作方式
1. 以圖找圖：224×224 白底等比例縮放 → MobileNet v2 → 1280 維特徵（原圖＋左右翻轉取平均）→ L2 正規化 → cosine，前 6 名。判斷類別＝最相似那張的類別；最高分 < 35% 提醒「圖庫可能沒有這類圖片」。
2. 語音查詢：Web Speech API（`zh-TW`，需網路）→ 文字 → 跟 `catalog.json` 子字串比對；也可直接輸入文字。
3. 點結果卡片 → 用那張圖再找其他相似圖片。
4. 特徵快取在 localStorage（`emb:v2:檔名:大小:雜湊`）。

## 2026-09-23 發佈與測試
- 本機（localhost）和正式網站（GitHub Pages，全新 Chrome profile）自我測試結果相同：變形找回原圖 14/15、排除自己後同類別 14/15、文字查詢 8/8，後端 webgl
- https 網址 → 手機相機、麥克風可直接使用

## 這次學到的事
1. 這台原本沒有 git / gh → `winget install --id Git.Git -e --scope user` 和 `winget install --id GitHub.cli -e`。
   裝完後**目前的 shell 的 PATH 不會更新**：工具裡先 `$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`；
   請使用者自己執行時給完整路徑 `! & "C:\Program Files\GitHub CLI\gh.exe" auth login --hostname github.com --git-protocol https --web`。
2. `gh auth login --web` 預設的 token **沒有 `workflow` scope** → push `.github/workflows/*.yml` 會被拒（`refusing to allow an OAuth App to create or update workflow`）。
   解法：不用 Actions，改成 Pages 從分支發佈（`gh api -X PUT repos/<o>/<r>/pages -f build_type=legacy -f "source[branch]=main" -f "source[path]=/"`）；
   或請使用者 `gh auth refresh -s workflow`。被拒的 commit 沒推上去過，可以 `--amend` 拿掉 workflow 檔再推。
3. 把 Pages 從 workflow 改成 legacy 後**不會自動建置** → `gh api -X POST repos/<o>/<r>/pages/builds`，再輪詢 `pages/builds/latest` 的 `status` 到 `built`。
4. 靜態網站沒有 `/api/images` → 改成事先產生 `images.json`；快取版本用**內容雜湊**，不用 mtime（git checkout 後 mtime 會變）。
5. PS 5.1 的 `Invoke-RestMethod` 讀 DevTools `/json` 回傳陣列時，`| ? type -eq 'page'` 會失敗 → 改用 `Invoke-WebRequest ... .Content | ConvertFrom-Json` 再 `| % { $_ }` 展開。
   `--remote-debugging-port=0` + 讀 `<user-data-dir>\DevToolsActivePort` 取得實際 port 比固定 port 穩。
6. 含中文的 `.ps1` 存成 UTF-8 with BOM（`..\0923\CLAUDE.md` 規則）。
