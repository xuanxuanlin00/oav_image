---
name: local-image-similarity-search
description: 在沒有 Python/Node 的 Windows 電腦上，做一套本機執行的「以圖找圖」圖片識別系統：上傳圖片、相機拍照、語音查詢，找出資料夾裡最相似的圖片。當使用者說「圖片辨識」「以圖找圖」「找最相似的圖片」「拍照查詢」「語音查圖片」時使用。範本：`0923\5.圖片識別系統`。
---

# 本機以圖找圖系統（PowerShell 伺服器 + TensorFlow.js）

適用環境：Windows 11、PowerShell 5.1、沒有 Python、沒有 Node、有 Chrome 或 Edge。

## 架構
```
瀏覽器 (http://localhost:8765)          PowerShell HttpListener
  index.html                    ←→      Start-Server.ps1
  lib/tf.min.js                          GET /api/images → 圖片清單 + catalog.json
  model/ (MobileNet v2 特徵)              GET 其他 → 靜態檔
```
辨識全部在瀏覽器做；伺服器只提供檔案。原因：相機和麥克風只能在 `localhost` 或 https 使用，`file://` 不行。

## 步驟

### 1. 看圖、確認環境
- 用 Read 工具逐張看圖片，整理出類別（檔名常有規則，例如 `A001` = A 類）和每張圖的名稱、顏色、型號 → 寫成 `catalog.json`（語音/文字查詢靠這個）
- 確認沒有 Python/Node、有 Chrome：`Get-Command python,node`

### 2. 下載模型到本機（之後離線可用）
```powershell
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force lib, model | Out-Null
Invoke-WebRequest 'https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/dist/tf.min.js' -OutFile lib\tf.min.js -UseBasicParsing
$base = 'https://www.kaggle.com/models/google/mobilenet-v2/TfJs/100-224-feature-vector/3'
Invoke-WebRequest "$base/model.json?tfjs-format=file" -OutFile model\model.json -UseBasicParsing
(Get-Content model\model.json -Raw | ConvertFrom-Json).weightsManifest.paths | % {
  Invoke-WebRequest "$base/$($_)?tfjs-format=file" -OutFile "model\$_" -UseBasicParsing }
```
輸入 `[N,224,224,3]`、值 0~1；輸出 1280 維特徵。

### 3. 伺服器（`Start-Server.ps1`）
- `HttpListener`，prefix `http://localhost:<port>/`（不需要系統管理員）
- 用 `BeginGetContext` + `WaitOne(500)` 輪詢，Ctrl+C 才能停止；`finally` 裡 `Stop()`
- 靜態檔要檢查：路徑在資料夾內、副檔名在白名單
- JSON 用 UTF-8 輸出；讀 `catalog.json` 用 `[IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)`
- 含中文 → 存成 **UTF-8 with BOM**

### 4. 前端（`index.html`）
- 特徵：canvas 等比例縮放到 224 白底（`imageSmoothingQuality='high'`）→ 原圖＋翻轉 → `model.predict` → 平均 → L2 正規化 → cosine
- **載入模型後先用 `tf.zeros` 暖機**，不然第一張圖的特徵可能是錯的
- `loadImage`：`onload` 後再 `await img.decode()`
- 上傳：file input + 拖曳 + Ctrl+V 貼上
- 相機：`getUserMedia({ video: { facingMode: 'environment' } })` → 畫到 canvas → 查詢
- 語音：`webkitSpeechRecognition`，`lang='zh-TW'` → 文字 → 去掉「我要找、的、圖片…」→ 跟名稱/關鍵字/類別同義詞做子字串比對；有提到類別就只在該類別排序。**一定要附文字輸入框**（語音需要網路、Firefox 不支援）
- 特徵快取到 localStorage（key 含檔名＋大小＋修改時間，try/catch 包起來）
- 加 `?selftest=1` 自我測試：變形查詢找回原圖、排除自己後 top-1 同類別、文字查詢案例

### 5. 驗證（headless Chrome + DevTools protocol）
`--dump-dom --virtual-time-budget` 會卡住，改用：
```powershell
Start-Process chrome -ArgumentList '--headless=new','--remote-debugging-port=9333',"--user-data-dir=$env:TEMP\x",
  '--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream','about:blank'
$tab = (Invoke-RestMethod http://127.0.0.1:9333/json | ? type -eq 'page')[0]
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$tab.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
# 送 {id, method:'Page.navigate'} → 輪詢 {method:'Runtime.evaluate', params:{expression, returnByValue:true, awaitPromise:true}}
# 截圖：Page.captureScreenshot → base64 → WriteAllBytes
```
- 用**全新的 user-data-dir** 測一次（重現第一次開啟、沒有快取的情況）
- 檢查：狀態列「就緒」、自我測試數字、相機（假鏡頭）拍照後有結果、上傳、點卡片、文字查詢
- 跑完要關掉測試用的 chrome（用 CommandLine 含 user-data-dir 找出來 Stop-Process）

## 常見錯誤對照
| 症狀 | 原因 | 解法 |
|---|---|---|
| 相機/麥克風打不開 | 用 `file://` 或非 localhost 開啟 | 從 `http://localhost:8765/` 開 |
| 語音顯示 network 錯誤 | Chrome/Edge 語音辨識要連雲端 | 連網路，或用文字查詢 |
| 某張圖跟什麼都不像（相似度 ~20%） | WebGL 第一次執行沒暖機 | 載入後先 `predict(tf.zeros(...))` |
| 同一張圖每次特徵不一樣 | canvas 縮圖品質不固定 | `imageSmoothingQuality='high'` + `img.decode()` |
| Ctrl+C 停不了伺服器 | `GetContext()` 阻塞 | `BeginGetContext` + `WaitOne(500)` |
| 中文變亂碼 | .ps1 沒有 BOM | 存成 UTF-8 with BOM |
