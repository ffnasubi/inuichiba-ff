# ===============================================
# PowerShell Script: fix-require-env.ps1
# 🔧 env.js を関数形式で呼び出すよう require() を置換
# 相対パスも自動調整！
# ===============================================

$baseDir = "functions"
$target = "lib/env"
$files = Get-ChildItem -Path $baseDir -Recurse -Filter *.js

foreach ($file in $files) {
    $filePath = $file.FullName
    $content = Get-Content $filePath -Raw

    # すでに () が付いている場合はスキップ
    if ($content -match "require\(['""][\.\/]+$target['""]\)\(\)") {
        continue
    }

    # パスの深さに応じて相対パスを構築
    $fileDir = Split-Path -Parent $filePath
    $relPath = Resolve-Path -Relative -Path (Join-Path $fileDir "$baseDir/$target")
    $relPath = $relPath -replace '\\', '/' # Windows対策

    # 正規表現に変換（lib/env の前の相対パスだけ置き換え）
    $escapedTarget = [regex]::Escape($target)
    $pattern = "require\(['""]([\.\/]+)$escapedTarget['""]\)"
    $replacement = "require('$matches[1]$target')()"

    # 手動で文字列差し替え（正規表現置換）
    $newContent = [regex]::Replace($content, $pattern, {
        param($m)
        "require('${($m.Groups[1].Value)}$target')()"
    })

    if ($newContent -ne $content) {
        Write-Host "✅ 修正済: $($file.FullName)" -ForegroundColor Cyan
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
    }
}

Write-Host "`n🎉 すべての require('～/lib/env') を require('～/lib/env')() に修正しました！" -ForegroundColor Green
