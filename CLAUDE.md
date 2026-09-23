# CLAUDE.md

本資料夾：本機執行的**圖片識別（以圖找圖）系統**。使用者可以用「上傳圖片」「相機拍照」「語音查詢」三種方式，找出圖庫中最相似的圖片。
圖庫就是這個資料夾裡的圖片檔（`*.jpg/.jpeg/.png/.webp/.bmp/.gif`），不需要資料庫。PowerShell/Excel 通用注意事項請看 `..\CLAUDE.md`。

## 檔案
- `start.bat`：雙擊啟動（呼叫 `Start-Server.ps1`，並自動開啟瀏覽器）
- `Start-Server.ps1`：PowerShell `HttpListener` 本機伺服器，只聽 `http://localhost:8765/`（參數 `-Port`、`-NoBrowser`）
  - `GET /api/images`：列出資料夾中的圖片 + `catalog.json` 的名稱/類別/關鍵字
  - 其他路徑：提供靜態檔（只允許資料夾內、限定副檔名；`..` 會回傳 403/404）
- `index.html`：整個前端（辨識都在瀏覽器裡做）
- `catalog.json`：每張圖的 `name`、`category`、`keywords`，以及類別的同義詞（語音/文字查詢用）
- `lib/tf.min.js`：TensorFlow.js 4.22.0（已下載到本機）
- `model/`：MobileNet v2 1.00 224 feature-vector（TF.js graph model，約 8.4 MB，已下載到本機）
- 圖片：`A001_1.jpg`… 檔名開頭代表類別：A 螺絲、B 狗、C 木工機械、D 鋸片、E 汽車（各 3 張）

## 執行
```powershell
.\start.bat
# 或
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-Server.ps1            # 會自動開瀏覽器
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-Server.ps1 -NoBrowser
```
瀏覽器開 `http://localhost:8765/`（**一定要用 localhost**，相機和麥克風只在 localhost / https 才能用；直接雙擊 index.html 用 file:// 開啟不能用）。
自我測試：`http://localhost:8765/?selftest=1`（不使用快取，重新計算所有特徵並列出測試結果）。

## 運作方式
1. 以圖找圖：圖片等比例縮放到 224×224 白底 → MobileNet v2 → 1280 維特徵（原圖＋左右翻轉取平均）→ L2 正規化 → 跟圖庫算 cosine 相似度，列出前 6 名。
   判斷類別＝最相似那張的類別（試過前 3 名投票：每類只有 3 張，排除自己後會被別類蓋過）。最高分 < 35% 會提醒「圖庫可能沒有這類圖片」。
2. 語音查詢：Web Speech API（`zh-TW`）轉成文字 → 跟 `catalog.json` 的名稱、關鍵字、類別同義詞做子字串比對。
   有講到類別（例如「狗」「車」）就只在那個類別裡排序；「白色的狗」→ 比熊犬。也可以直接輸入文字。
3. 點結果卡片 → 用那張圖再找其他相似圖片（不列出自己）。
4. 圖庫特徵快取在瀏覽器 localStorage（key 含檔名、大小、修改時間；圖片換了會自動重算）。

## 新增圖片
把圖片複製到這個資料夾 → 在 `catalog.json` 的 `images` 加上名稱/類別/關鍵字（不加也可以，類別會顯示「未分類」，只是語音查詢找不到）→ 重新整理網頁。

## 2026-09-23 測試結果（headless Chrome，透過 DevTools protocol）
- 啟動＋建立 15 張索引約 5 秒（WebGL）；之後有快取約 1 秒
- 變形查詢（裁掉 15% 邊緣、旋轉 8 度、調暗）找回原圖：14/15（D001 被判成 D002，同類別）
- 排除自己後最相似的是同類別：14/15（B003 比熊犬坐在灰色椅子上，最近的是木工機械 37%）
- 文字查詢 8/8；相機（假鏡頭）、上傳、點卡片都正常

## 這次學到的事
1. 這台沒有 Python / Node → 用 **TensorFlow.js 在瀏覽器裡跑模型**，PowerShell `HttpListener` 只負責提供檔案。模型和 tf.min.js 都下載到本機，**以圖找圖完全離線**。
   模型來源：`https://www.kaggle.com/models/google/mobilenet-v2/TfJs/100-224-feature-vector/3/model.json?tfjs-format=file`（shard 也要加 `?tfjs-format=file`）。
2. **語音辨識（Chrome/Edge 的 Web Speech API）需要網路**，語音會送到雲端辨識；離線時請改用文字輸入。Firefox 不支援。
3. WebGL **第一次執行模型的結果可能不正確**（著色器還在編譯）→ 載入模型後先用 `tf.zeros` 暖機一次。
4. canvas 縮圖要設 `imageSmoothingQuality = 'high'`，圖片 `onload` 後再 `await img.decode()`；否則同一張大圖第一次和之後算出的特徵會不同（cosine 只有 0.97）。
5. `chrome --headless --dump-dom --virtual-time-budget` 等非同步載入模型會卡住 → 改用 `--remote-debugging-port` + `ClientWebSocket` 送 `Runtime.evaluate` 輪詢結果、`Page.captureScreenshot` 截圖。
   測相機加 `--use-fake-ui-for-media-stream --use-fake-device-for-media-stream`。
6. HttpListener 的 `GetContext()` 會擋住 Ctrl+C → 改用 `BeginGetContext` + `AsyncWaitHandle.WaitOne(500)` 輪詢。
7. `Start-Server.ps1` 含中文 → 存成 UTF-8 with BOM（`..\CLAUDE.md` 規則 1）。
