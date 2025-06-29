# PowerShell スクリプト: .env.set_secrets-ff.ps1
# --------------------------------------------------
# ⓵.env.secrets.ff*.txt を読み込む
# ⓶ GitHub Secretsに登録
# ⓷	Firebase Config の該当キーを削除
# ⓸	Firebase Config に再注入（セット）
# --------------------------------------------------
# - Supabase のキー名は SUPABASE_SERVICE_ROLE_KEY → GitHub Secrets では SUPABASE_KEY_DEV/PROD に変換
# - 他はそのまま _FFDEV / _FFPROD の suffix を維持
# - コメント行 (#) 、空行はスキップ
# --------------------------------------------------
# 事前条件:
# - gh CLI がインストール済みであること - 	https://cli.github.com/ から可能
# - gh CLI 確認 「gh --version」「gh auth status」 
# - gh repo view が成功すること（カレントディレクトリが対象内であること）
# - gh auth login により GitHub 認証が済んでいること
# --------------------------------------------------
# powershell -ExecutionPolicy Bypass -File .env.set_secrets-ff.ps1 -envSuffix ffdev
# powershell -ExecutionPolicy Bypass -File .env.set_secrets-ff.ps1 -envSuffix ffprod
# --------------------------------------------------


param (
  [string]$envSuffix = "ffdev"  # 例: ffdev または ffprod
)

Write-Host "🔐 .env の内容を Functions Config に登録中..." -ForegroundColor Cyan

# 環境変数ファイル
$envFile = ".env.secrets.$envSuffix.txt"

if (-Not (Test-Path $envFile)) {
  Write-Host "❌ ファイルが見つかりません: $envFile" -ForegroundColor Red
  exit 1
}

# .env を読み込む
$lines = Get-Content $envFile | Where-Object { $_ -and ($_ -notmatch '^#') }

foreach ($line in $lines) {
  if ($line -match '^\s*([^=]+)\s*=\s*(.+)$') {
    $key = $matches[1].Trim()
    $val = $matches[2].Trim()

    # Firebase Config 用キー名変換
    switch ($key) {
      "channel_access_token_$envSuffix"       { $configKey = "line.channel_access_token_$envSuffix" }
      "channel_secret_$envSuffix"             { $configKey = "line.channel_secret_$envSuffix" }
      "supabase_service_role_key_$envSuffix"  { $configKey = "supabase.supabase_key_$envSuffix" }
      default                                 { $configKey = $key.ToLower() }
    }

    # 削除（存在してもなくてもOK）
    Write-Host "🗑 不要な Firebase Config [$configKey] を削除中..."
    firebase functions:config:unset $configKey --project "inuichiba-$envSuffix"

    # 登録（key=val 形式）
    Write-Host "⚙️ Firebase Config [$configKey] を登録中..."
    firebase functions:config:set "$configKey=$val" --project "inuichiba-$envSuffix"

    # GitHub Secrets 名は大文字に統一（例: CHANNEL_ACCESS_TOKEN_FFDEV）
    # $githubSecretKey = $key.ToUpper()
    # Write-Host "🔐 GitHub Secret [$githubSecretKey] 登録中..."
    # gh secret set $githubSecretKey -b "$val" --repo inuichiba/inuichiba-ff
  }
}

Write-Host "✅ 完了！GitHub Secrets + Firebase Config が更新されました。" -ForegroundColor Green
