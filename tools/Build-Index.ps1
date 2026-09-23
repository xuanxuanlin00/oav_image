# 產生 images.json：列出 images/ 資料夾裡的圖片（檔名、大小、內容雜湊）
# 前端讀這個檔 + catalog.json 建立圖庫。GitHub Actions 部署時會自動重跑，本機預覽時 Start-Server.ps1 也會先跑。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Index.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$imgDir = Join-Path $root 'images'
$imageExt = @('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif')

$sha = [Security.Cryptography.SHA256]::Create()
$list = foreach ($f in Get-ChildItem -LiteralPath $imgDir -File | Where-Object { $imageExt -contains $_.Extension.ToLower() } | Sort-Object Name) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    # 用內容雜湊當快取版本（git checkout 後修改時間會變，不能用 mtime）
    $hash = -join ($sha.ComputeHash($bytes)[0..5] | ForEach-Object { $_.ToString('x2') })
    [ordered]@{ file = $f.Name; size = $f.Length; hash = $hash }
}
$json = ConvertTo-Json -InputObject @($list) -Depth 3 -Compress
[IO.File]::WriteAllText((Join-Path $root 'images.json'), $json, (New-Object Text.UTF8Encoding($false)))
Write-Host "images.json：$(@($list).Count) 張圖片"
