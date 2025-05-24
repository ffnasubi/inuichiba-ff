$path = ".env.secrets.ffprod.txt"
$bytes = [System.IO.File]::ReadAllBytes($path)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "⚠️ BOM付きUTF-8です：$path" -ForegroundColor Red
} else {
    Write-Host "✅ BOMなしUTF-8です：$path" -ForegroundColor Green
}
