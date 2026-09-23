# 圖片識別系統（以圖找圖）

網站：https://xuanxuanlin00.github.io/oav_image/

用手機拍照、上傳圖片或語音/文字查詢，找出圖庫中最相似的圖片。辨識全部在瀏覽器裡用 TensorFlow.js（MobileNet v2）完成，不需要後端伺服器。

## 新增圖片
1. 把圖片放進 `images/`
2. 在 `catalog.json` 的 `images` 加上名稱、類別、關鍵字（可省略，會顯示「未分類」）
3. 雙擊 `publish.bat`（會重建 `images.json`、commit、push）

GitHub Pages 直接從 `main` 分支發佈，約 1 分鐘後生效。

## 本機預覽
雙擊 `start.bat`，開 http://localhost:8765/ 。自我測試：`?selftest=1`。
