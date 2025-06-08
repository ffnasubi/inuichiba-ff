# PowerShell スクリプト: .env.set_secrets-gh.ps1
# --------------------------------------------------
# GitHub Secrets に .env.secrets.ffdev.txt / .env.secrets.ffprod.txt の内容を登録する
# - リポジトリ単位の Secrets を一括登録
# - Suffix (_PROD / _DEV) 付きキーも自動対応
# - コメント行 (#) はスキップ
#
# 事前条件:
# - gh CLI がインストール済みであること
# - gh auth login により GitHub 認証が済んでいること
# --------------------------------------------------
# powershell -ExecutionPolicy Bypass -File .env.set_secrets-gh.ps1 -env ffdev
# powershell -ExecutionPolicy Bypass -File .env.set_secrets-gh.ps1 -env ffprod
# --------------------------------------------------


param(
  [ValidateSet("ffdev", "ffprod")]
  [string]$env = "ffdev"
)

$envPath = ".env.secrets.$env.txt"
if (-not (Test-Path $envPath)) {
  Write-Host "❌ Secretsファイルが見つかりません: $envPath" -ForegroundColor Red
  exit 1
}

# 🔍 GitHub CLIログイン確認
if (-not (gh auth status 2>$null)) {
  Write-Host "❌ gh CLI に未ログインです。gh auth login を実行してください。" -ForegroundColor Red
  exit 1
}

# 📦 リポジトリ名取得（例：inuichiba/inuichiba-ff）
$repo = gh repo view --json nameWithOwner --jq ".nameWithOwner"
if (-not $repo) {
  Write-Host "❌ リポジトリ名の取得に失敗しました。gh repo view が使える状態にしてください。" -ForegroundColor Red
  exit 1
}

Write-Host "🚀 GitHub Secrets 登録開始: $repo ($env)"

$lines = Get-Content $envPath -Encoding UTF8
foreach ($line in $lines) {
  if ($line -match "^\s*#" -or $line.Trim() -eq "") { continue }

  $parts = $line -split "=", 2
  if ($parts.Count -ne 2) { continue }

  $key = $parts[0].Trim()
  $val = $parts[1].Trim()

  # suffix の付け方: CHANNEL_ACCESS_TOKEN → CHANNEL_ACCESS_TOKEN_DEV など
  if ($key -match "_(PROD|DEV)$") {
    $fullKey = $key
  } elseif ($key -match "SUPABASE") {
    # SUPABASE 系は suffix なし（共通）
    $fullKey = $key
  } else {
		if ($env -eq "ffprod") {
  		$suffix = "_PROD"
		} else {
  		$suffix = "_DEV"
		}
    $fullKey = "$key$suffix"
  }

  Write-Host "🔐 [$fullKey] を登録中..."
  gh secret set $fullKey --body "$val" --repo $repo
}

Write-Host "✅ Secrets の登録が完了しました！" -ForegroundColor Green
