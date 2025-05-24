# .env.set_secrets.ps1（環境依存Secrets + 共通Secrets対応版）
# ✅ .env.secrets.ff*.txt から環境別キー（_PROD / _DEV）を登録
# ✅ SUPABASE_SERVICE_ROLE_KEY など共通キーは環境にかかわらず常に登録

# .env.set_secrets.ps1 - Secrets 登録＋古いバージョン削除（確認付き）＋状態一覧出力
# .env.secrets.ffprod.txt/.env.secrets.ffdev.txt を読み込んで Firebase Secrets に一括登録
# secrets登録先を間違えてautomaticにして、課金対象にならないようにする(正しくは以下)
# gcloud secrets create を --replication-policy=user-managed --locations=asia-northeast1 に変更

# .ps1のファイル形式は UTF-8(BOM付き) であること

# 課金はプロジェクト単位ではなく、クレジットカード単位と思うこと(ffprod/ffdev含めて10個まで無料)
# しかもバージョン毎に課金される
# だからできるだけバージョンは1にとどめ、2以降になっちゃったら以前のものはすぐdestroyすること(disabledじゃダメ)

# 環境ごとの設定
# .env.set_secrets.ps1
# 指定した環境（ffdev / ffprod）に対応する Secrets を Firebase Secret Manager に登録し、複数登録は
# 以前のものを削除すること

# .env.set_secrets.ps1 - Secrets 登録+古いバージョン削除（確認付き）＋状態一覧出力
# ========================================================================
# ✅ 使い方(管理者権限で)：
# powershell -ExecutionPolicy Bypass -File .\.env.set_secrets.ps1 -Env ffdev  -deleteOldVersions
# powershell -ExecutionPolicy Bypass -File .\.env.set_secrets.ps1 -Env ffprod -deleteOldVersions
# -deleteOldVersions: 古い Secrets バージョンを確認付きで削除（省略可だけど省略しないでね）
#
# 🔐 Secrets 定義ファイルは以下の形式でルートに用意してください：
# .env.secrets.ffdev.txt / .env.secrets.ffprod.txt
#   内容例: CHANNEL_SECRET_DEV=abc123 	← =の前後にはスペース不可
#   内容例: # CHANNEL_SECRET_DEV=abc123 ← 1列目に# を入れればコメントとみなされる
# ========================================================================

param(
    [string]$Env = "ffdev",         # ← ここで "ffprod" または "ffdev" を指定（既定値は ffdev）
    [switch]$deleteOldVersions      # ← 古いバージョンを削除する（--deleteOldVersions）指定推奨
)

# マッピング定義
$projectIdMap = @{ ffdev = "inuichiba-ffdev"; ffprod = "inuichiba-ffprod" }
$envPathMap   = @{ ffdev = ".env.secrets.ffdev.txt"; ffprod = ".env.secrets.ffprod.txt" }

$projectId = $projectIdMap[$Env]
$envPath   = $envPathMap[$Env]
$env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.$Env.json"

if (-not $projectId) {
  Write-Host "❌ 無効な環境名です。-Env ffdev または -Env ffprod を指定してください。" -ForegroundColor Red
  exit 1
}
if (-not (Test-Path $envPath)) { 
  Write-Host "❌ Secretsファイルが見つかりません。: $envPath" -ForegroundColor Red
  exit 1 
}
if (-not (Test-Path $envPath)) {
  Write-Host "❌ Secretsファイルが見つかりません: $envPath" -ForegroundColor Red
  exit 1
}

# 登録前の Secrets 一覧
Write-Host "📋 登録前の Secrets 一覧:" -ForegroundColor Yellow
Invoke-Expression "gcloud secrets list --project=$projectId --format='table(name, replication.policy)'"

# Secret Manager API を有効化（初回のみ）
Write-Host "🚀 [$Env] Secrets の登録を開始します（.envファイル準拠）..." -ForegroundColor Cyan
& gcloud services enable secretmanager.googleapis.com --project=$projectId | Out-Null

# 登録対象の prefix を判定（例: _PROD または _DEV）
if ($Env -eq "ffprod") {
  $envSuffix = "_PROD"
} else {
  $envSuffix = "_DEV"
}
$commonKeys = @("SUPABASE_SERVICE_ROLE_KEY")

# Secrets の登録処理開始
$lines = Get-Content $envPath -Encoding UTF8

foreach ($line in $lines) {
  if ($line.Trim() -eq "" -or $line.Trim().StartsWith("#")) { continue }

  $parts = $line -split "=", 2
  if ($parts.Count -ne 2) {
    Write-Host "⚠️ 無効な形式の行のためスキップします: $line" -ForegroundColor Yellow
    continue
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()

  # 共通キーは常に登録、それ以外は _PROD または _DEV のみ登録
  if (-not ($commonKeys.Contains($key) -or $key -like "*$envSuffix")) {
    Write-Host "⏭ 無視: $key はこの環境の登録対象外のためスキップ" -ForegroundColor Gray
    continue
  }

  $exists = & gcloud secrets describe $key --project=$projectId 2>$null
  if ($exists) {
    Write-Host "🔁 [$key] は既に存在 → 新バージョン追加中..." -ForegroundColor Yellow
  } else {
    Write-Host "🆕 [$key] を新規作成中..." -ForegroundColor Cyan
    & gcloud secrets create $key --replication-policy="user-managed" --locations="asia-northeast1" --project=$projectId | Out-Null
  }
  
  $tempFile = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tempFile, $value, [System.Text.Encoding]::UTF8)  # 安全なUTF-8書き込み
  & gcloud secrets versions add $key --data-file=$tempFile --project=$projectId | Out-Null
  Remove-Item $tempFile

  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ [$key] 登録完了！" -ForegroundColor Green
  } else {
    Write-Host "❌ [$key] 登録に失敗しました" -ForegroundColor Red
  }
}

# ✅ レプリケーション確認
Write-Host "`n🛡 登録済み Secrets のレプリケーションポリシーを確認中..." -ForegroundColor Cyan

$allSecrets = gcloud secrets list --project=$projectId --format="value(name)"
$badReplicas = @()

foreach ($secret in $allSecrets) {
  $replication = gcloud secrets describe $secret `
    --project=$projectId `
    --format="value(replication.userManaged.replicas[0].location)"

  if ($replication -ne "asia-northeast1") {
    Write-Host "⚠️ $secret は asia-northeast1 に複製されていません！（→ $replication）" -ForegroundColor Red
    $badReplicas += $secret
  } else {
    Write-Host "✅ $secret は正しく asia-northeast1 に複製されています。" -ForegroundColor Green
  }
}

if ($badReplicas.Count -eq 0) {
  Write-Host "`n🌟 すべての Secrets が正しく user-managed + asia-northeast1 です！" -ForegroundColor Green
} else {
  Write-Host "`n❌ 複製リージョンに問題のある Secret が存在します：" -ForegroundColor Red
  $badReplicas | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }

  Write-Host "`n🔎 後で以下のコマンドで削除し再登録しましょう：" -ForegroundColor Cyan
  Write-Host "gcloud secrets delete <secret-name> --project=$projectId" -ForegroundColor Yellow
  Write-Host "gcloud secrets create <secret-name> --replication-policy=user-managed --locations=asia-northeast1 --project=$projectId" -ForegroundColor Yellow
}


# 登録後の Secrets 一覧
Write-Host "`n📋 登録後の Secrets 一覧:" -ForegroundColor Yellow
Invoke-Expression "gcloud secrets list --project=$projectId --format='table(name, replication.policy)'"

# Firebase Deploy と古い Secrets の削除（対話付き）
if ($deleteOldVersions) {
  Write-Host "`n🚀 Firebase Deploy を実行中... ($projectId)" -ForegroundColor Cyan
  Write-Host "⚠️ この操作では古い Secret のバージョン削除確認が表示されます。削除する場合は 'y' を入力してください。" -ForegroundColor Yellow

  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firebase Deploy 完了！" -ForegroundColor Green
  } else {
    Write-Host "❌ Firebase Deploy に失敗しました" -ForegroundColor Red
  }

  # バージョン削除（1件ずつ確認付き）
  Write-Host "`n🧹 Secrets の古いバージョン削除（1件ずつ確認付き）を開始します..." -ForegroundColor Cyan

  $secrets = gcloud secrets list --project=$projectId --format="value(name)"

  foreach ($secret in $secrets) {
    Write-Host "`n🔐 Secret: $secret" -ForegroundColor Yellow

    $versions = gcloud secrets versions list $secret `
      --project=$projectId `
      --sort-by="~createTime" `
      --format="value(name,state)"

    $latestEnabledSkipped = $false

    foreach ($line in $versions) {
      $parts = $line -split "\s+", 2
      $version = $parts[0]
      $state = $parts[1]

      if (-not $latestEnabledSkipped -and $state -eq "ENABLED") {
        Write-Host "⏭ バージョン $version は最新の ENABLED → スキップ" -ForegroundColor DarkGray
        $latestEnabledSkipped = $true
        continue
      }

      if ($state -eq "DESTROYED") {
        Write-Host "☠️ バージョン $version はすでに DESTROYED → 無視" -ForegroundColor Gray
        $latestEnabledSkipped = $true
        continue
      }

      if ($state -eq "DESTROYED") {
        Write-Host "☠️ バージョン $version は DESTROYED → 無視" -ForegroundColor Gray
        continue
      }

      Write-Host "⚠️ [$secret] バージョン $version は $state 状態です。" -ForegroundColor Magenta
      $answer = Read-Host "❓ 削除しますか？（y/N）"
      if ($answer -eq "y") {
        Write-Host "🗑 削除中: $secret バージョン $version" -ForegroundColor Red
        gcloud secrets versions destroy $version --secret=$secret --project=$projectId --quiet
      } else {
        Write-Host "⏭ スキップ: $secret バージョン $version" -ForegroundColor Gray
      }
    }
  }
}


# 最後にすべてのSecretsのバージョン状態を一覧出力
Write-Host "`n📊 全Secretsのバージョン状態一覧:enabledがひとつだけであることを確認してください" -ForegroundColor Cyan
$allSecrets = gcloud secrets list --project=$projectId --format="value(name)"
foreach ($secret in $allSecrets) {
  Write-Host "`n🔎 Secret: $secret" -ForegroundColor Yellow
  gcloud secrets versions list $secret `
    --project=$projectId `
    --sort-by="name" `
    --format="table(name, state, createTime)"
}




# 使い方ヒントを表示
Write-Host "`n💡 補足：バージョン操作の参考コマンド" -ForegroundColor Cyan
Write-Host "🔸 特定バージョンを削除する場合：" -ForegroundColor Yellow
Write-Host "    gcloud secrets versions destroy VERSION_NUMBER(1or2or..) --secret=SECRET_NAME --project=$projectId --quiet"
Write-Host "🔸 特定バージョンを ENABLED に戻す場合：" -ForegroundColor Yellow
Write-Host "    gcloud secrets versions enable VERSION_NUMBER --secret=SECRET_NAME --project=$projectId"
Write-Host "🔸 特定バージョンを DISABLED に変更する場合(通常使わない)：" -ForegroundColor Cyan
Write-Host "    gcloud secrets versions disable VERSION_NUMBER --secret=SECRET_NAME --project=$projectId"


# 完了メッセージ
Write-Host "`n🌟 [$Env] Secrets 登録がすべて完了しました！" -ForegroundColor Green
exit 0

