# .env.set_firebase_config.ps1
# 古いFirebase config を削除して、.env.secrets.ff** を読み込んで Firebase Config に登録する
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\.env.set_firebase_config.ps1 -envSuffix ffdev
#   powershell -ExecutionPolicy Bypass -File .\.env.set_firebase_config.ps1 -envSuffix ffprod

param (
  [string]$envSuffix = "ffdev"  # or "ffprod"
)

# 🔹 1. .env ファイル読み込み
$envFilePath = ".env.secrets.$envSuffix.txt"
if (-not (Test-Path $envFilePath)) {
  Write-Host "❌ ファイルが見つかりません: $envFilePath" -ForegroundColor Red
  exit 1
}

Write-Host "📄 読み込み中: $envFilePath" -ForegroundColor Cyan
$content = Get-Content $envFilePath -Encoding UTF8


# 🔹 1.5 Firebase Config の事前削除（キー名を抽出して個別に削除）
Write-Host "`n🧹 古い Firebase Config を削除中..." -ForegroundColor Yellow

$keysToDelete = @()

switch ($envSuffix) {
  "ffdev" {
    $keysToDelete = @(
      "line.channel_access_token_ffdev",
      "line.channel_secret_ffdev",
      "supabase.service_key_ffdev"
    )
  }
  "ffprod" {
    $keysToDelete = @(
      "line.channel_access_token_ffprod",
      "line.channel_secret_ffprod",
      "supabase.service_key_ffprod"
    )
  }
  default {
    Write-Host "❌ 未対応の環境: $envSuffix" -ForegroundColor Red
    exit 1
  }
}

foreach ($key in $keysToDelete) {
  Write-Host "  🔸 削除: $key" -ForegroundColor Gray
  firebase functions:config:unset $key --project="inuichiba-$envSuffix" | Out-Null
}

Write-Host "✅ 削除完了" -ForegroundColor Green


# 🔹 2. フィルタリング・整形処理
$configMap = @{}

foreach ($line in $content) {
  $line = $line.Trim()
  if ($line.Length -eq 0 -or $line.StartsWith("#")) {
    continue  # 空行・コメント行スキップ
  }

  $kv = $line -split "=", 2
  if ($kv.Count -ne 2) {
    Write-Host "⚠️ 無効な形式（=なし）: $line" -ForegroundColor Yellow
    continue
  }

  $key = $kv[0].Trim()
  $value = $kv[1].Trim()

  # BOM削除 + 制御文字除去（BOM: U+FEFF）
  if ($value.Length -gt 0 -and $value[0] -eq [char]0xFEFF) {
    $value = $value.Substring(1)
  }
  $value = ($value -replace '[\u0000-\u001F]', '').Trim()

  # 🔹 3. Firebase Configキーへマッピング
  switch ($key) {
    # 🔹 ffdev 向け
    "CHANNEL_ACCESS_TOKEN_FFDEV" {
      if ($envSuffix -eq "ffdev") {
        $configKey = "line.channel_access_token_ffdev"
      } else {
        Write-Host "⚠️ スキップ: $key は ffdev 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }
    "CHANNEL_SECRET_FFDEV" {
      if ($envSuffix -eq "ffdev") {
        $configKey = "line.channel_secret_ffdev"
      } else {
        Write-Host "⚠️ スキップ: $key は ffdev 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }
    "SUPABASE_SERVICE_ROLE_KEY_FFDEV" {
      if ($envSuffix -eq "ffdev") {
        $configKey = "supabase.service_key_ffdev"
      } else {
        Write-Host "⚠️ スキップ: $key は ffdev 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }

    # 🔹 ffprod 向け
    "CHANNEL_ACCESS_TOKEN_FFPROD" {
      if ($envSuffix -eq "ffprod") {
        $configKey = "line.channel_access_token_ffprod"
      } else {
        Write-Host "⚠️ スキップ: $key は ffprod 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }
    "CHANNEL_SECRET_FFPROD" {
      if ($envSuffix -eq "ffprod") {
        $configKey = "line.channel_secret_ffprod"
      } else {
        Write-Host "⚠️ スキップ: $key は ffprod 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }
    "SUPABASE_SERVICE_ROLE_KEY_FFPROD" {
      if ($envSuffix -eq "ffprod") {
        $configKey = "supabase.service_key_ffprod"
      } else {
        Write-Host "⚠️ スキップ: $key は ffprod 専用です（現在: $envSuffix）" -ForegroundColor DarkGray
        continue
      }
    }

    default {
      Write-Host "⚠️ 無効なキーが検出されました: $key（この行は無視されます）" -ForegroundColor Yellow
      continue
    }
  }

  # 🔐 ログ（値の先頭だけ表示）
  $maskedValue = if ($value.Length -ge 5) { $value.Substring(0,5) + "..." } else { "(短すぎ)" }
  Write-Host "📝 登録予定: $configKey = $maskedValue" -ForegroundColor Cyan

  $configMap[$configKey] = $value
}


# 🔹 4. Firebase Functions に設定反映
if ($configMap.Count -eq 0) {
  Write-Host "⚠️ 設定すべき値がありません。処理を終了します。" -ForegroundColor Yellow
  exit 0
}


# 引数配列を構築
$configArgs = @()
foreach ($entry in $configMap.GetEnumerator()) {
  $configArgs += "$($entry.Key)=""$($entry.Value)"""
}


# ✅ 確認ログ：秘匿値を表示せず、キー名だけを確認ログに出す
Write-Host "`n🔧 確定された Firebase Config（キー名のみ）:" -ForegroundColor DarkCyan
$configMap.Keys | Sort-Object | ForEach-Object {
  Write-Host "  ✅ $_"
}


# firebase コマンド実行
Write-Host "🚀 Firebase Functions 設定を登録中..." -ForegroundColor Green
& firebase functions:config:set @configArgs --project="inuichiba-$envSuffix"

if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Firebase Config の登録に失敗しました" -ForegroundColor Red
  exit 1
}

Write-Host "`n🎉 完了: Firebase Config を登録しました (inuichiba-$envSuffix)" -ForegroundColor Green
