param(
  [string]$env = "ffdev"
)

$ACCESS_TOKEN = ""

switch ($env) {
  "ffprod" {
    $ACCESS_TOKEN = "/0/AD5jmDpc4mgJ3/XCZ7nH28vnxRRhddsMnE9DJV6fo7Iod3vvBwSF7v9utHEInCzZcjkDLFGE3LYZB2Q/PZEjtJSOm0sn8a7Bcu/v6DHdbx/cHkjdv6oWRmcToLKPYZmh1gEcSjHr0A/rSTxhmbAdB04t89/1O/w1cDnyilFU="
  }
  "ffdev" {
    $ACCESS_TOKEN = "D2Fhevgr/6pVFJhSgsfqVNEW6hiZYN8zZcx21wWq/EPctqOO/Fs2YdsXJsVnB8JjRkaFsBSRNXKzZdfduUXn9AjAaleGMaC2FGeQqsIR3+SFfQ9CM2ZaqwrBjEqCuwUsOS0hdSNNXB8S4t01RamnDwdB04t89/1O/w1cDnyilFU="
  }
  default {
    Write-Host "❌ 不正な環境です: $env。-env ffdev か -env ffprod を指定してください。" -ForegroundColor Red
    exit 1
  }
}

Write-Host "`n🔍 [$env] リッチメニュー診断開始..." -ForegroundColor Cyan

# 📋 現在のリッチメニュー一覧
Write-Host "`n📋 現在のリッチメニュー一覧:"
& curl.exe -s -H "Authorization: Bearer $ACCESS_TOKEN" https://api.line.me/v2/bot/richmenu/list

# 📋 default設定
Write-Host "`n📋 全ユーザーへのリッチメニュー設定状況:"
& curl.exe -s -H "Authorization: Bearer $ACCESS_TOKEN" https://api.line.me/v2/bot/user/all/richmenu

Write-Host "`n✅ 診断完了" -ForegroundColor Green
