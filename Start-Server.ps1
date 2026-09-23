# 圖片識別系統 — 本機預覽伺服器（只聽 localhost）；正式網站在 GitHub Pages
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-Server.ps1 [-Port 8765] [-NoBrowser]
param(
    [int]$Port = 8765,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$mime = @{
    '.html' = 'text/html; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.bin' = 'application/octet-stream'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'
    '.png' = 'image/png'; '.webp' = 'image/webp'; '.bmp' = 'image/bmp'; '.gif' = 'image/gif'
}

function Send-Bytes($res, [byte[]]$bytes, [string]$type, [int]$status = 200) {
    $res.StatusCode = $status
    $res.ContentType = $type
    $res.Headers['Cache-Control'] = 'no-cache'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
}
function Send-Text($res, [string]$text, [string]$type, [int]$status = 200) {
    Send-Bytes $res ([Text.Encoding]::UTF8.GetBytes($text)) $type $status
}

# 先重建 images.json（跟 GitHub Actions 部署時一樣）
& (Join-Path $root 'tools\Build-Index.ps1')

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "圖片識別系統已啟動：$prefix （按 Ctrl+C 停止）"
if (-not $NoBrowser) { Start-Process $prefix }

try {
    while ($listener.IsListening) {
        $ar = $listener.BeginGetContext($null, $null)
        while (-not $ar.AsyncWaitHandle.WaitOne(500)) { }   # 用輪詢等待，Ctrl+C 才能中斷
        $ctx = $listener.EndGetContext($ar)
        $req = $ctx.Request; $res = $ctx.Response
        try {
            $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
            if ($path -eq '/') { $path = '/index.html' }
            $rel = $path.TrimStart('/').Replace('/', '\')
            $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
            $ext = [IO.Path]::GetExtension($full).ToLower()
            if (-not $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $full -PathType Leaf) -or -not $mime.ContainsKey($ext)) {
                Send-Text $res 'Not Found' 'text/plain; charset=utf-8' 404
            }
            else {
                Send-Bytes $res ([IO.File]::ReadAllBytes($full)) $mime[$ext]
            }
            Write-Host ("{0:HH:mm:ss} {1} {2} {3}" -f (Get-Date), $req.HttpMethod, $path, $res.StatusCode)
        }
        catch {
            Write-Host "錯誤：$($_.Exception.Message)"
            try { Send-Text $res "Server error" 'text/plain; charset=utf-8' 500 } catch { }
        }
        finally {
            try { $res.Close() } catch { }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host '伺服器已停止'
}
