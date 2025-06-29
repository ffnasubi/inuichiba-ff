# ----------------------------------------------
# deploy-and-cleanup.ps1
# 通常のデプロイは必ずこのスクリプトでのみ行うこと！！
# 1. あらかじめ Artifact Registry を作り、GCR を使わない(Gen2の状態にした)上で
# 2. firebase functions:config:unsetで今のFirebase Config(環境変数)を削除し、
# 3. GitHub Secretsを読み込んで Firebase Functions に環境変数を設定し、
# 4. 登録が安定するまで待ち、
# 5. Firebase Functions をデプロイし、
# 6. デプロイが安定するまで待ち、
# 7. 不要なバケットなど課金対象を削除する統合スクリプト
# 
# 特に最初に1は必須。でないと GCR が作られて Gen1 でデプロイされてしまう
# (Gen2 移行を推奨されている)
# ⚠️ 特にffprodは必ずこのスクリプトでデプロイすること！
# またFF環境変数登録の前に以前の登録情報を削除しないと値が崩れる可能性有り
# ----------------------------------------------
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffdev
# ----------------------------------------------

# deploy-and-cleanup.ps1 - 改良版（PROD/DEV 共通化＋コメント付き）
param (
  [string]$env = ""
)

# ✅ プロジェクトIDのマッピング
switch ($env) {
  "ffprod" { 
    $projectId = "inuichiba-ffprod" 
  }
  "ffdev"  { 
    $projectId = "inuichiba-ffdev" 
  }
  default {
    Write-Host "❌ 未知の環境名です: $env（ffprod または ffdev を指定してください）" -ForegroundColor Red
    exit 1
  }
}

gcloud config set project $projectId | Out-Null

# ----------------------------------------------
# artifact-registry作成
# ----------------------------------------------
Write-Host "`n🚀 Gen2にするため artifact-registry を先に作ります（環境: $env）..." -ForegroundColor Cyan
if (-Not (Test-Path ".\setup-artifact-registry.ps1")) {
  Write-Host "❌ setup-artifact-registry.ps1 が見つかりません" -ForegroundColor Red
  exit 1
}
powershell -ExecutionPolicy Bypass -File .\setup-artifact-registry.ps1 -envName $env 


# ----------------------------------------------
# .env(secret)を読み込んでFirebase Configに登録する
# ----------------------------------------------
Write-Host "🔐 .env の内容を Functions Config に登録中..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .env.set_secrets-ff.ps1 -envSuffix $env


# ----------------------------------------------
# 登録が安定するまで60秒待つ
# ----------------------------------------------
Write-Host "`n🚀 Firebase Configが安定するまで60秒待ちます..." -ForegroundColor Cyan
for ($i = 60; $i -ge 1; $i--) {
  Write-Host -NoNewline "`r残り $i 秒..."
  Start-Sleep -Seconds 1
} 


# ----------------------------------------------
# 暫定措置：登録した環境変数(config)を確認する 評価が終わったら削除！！ 
# ----------------------------------------------
Write-Host "`n🚀 暫定措置：登録したfirebase functions:config:getして Configを表示します" -ForegroundColor Cyan
# firebase functions:config:get --project=$projectId
$maxRetry = 5
$success = $false

Write-Host "`n🔍 Firebase Config 取得中（最大 $maxRetry 回リトライ）..." -ForegroundColor Cyan

for ($i = 1; $i -le $maxRetry; $i++) {
    try {
        $result = firebase functions:config:get --project=$projectId | Out-String
        if ($result -and $result.Trim() -ne "") {
            Write-Host "`n✅ Firebase Config 取得成功！（$i 回目）" -ForegroundColor Green
            Write-Host "`n--- Firebase Config 内容 ---" -ForegroundColor DarkGray
            Write-Host $result.Trim()
            Write-Host "------------------------------`n" -ForegroundColor DarkGray
            $success = $true
            break
        } else {
            Write-Host "⚠️ 空の結果です（$i 回目）。再試行..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⏳ 取得失敗（$i 回目）: $_" -ForegroundColor DarkYellow
    }
    Start-Sleep -Seconds 5
}

if (-not $success) {
    Write-Host "❌ Firebase Config の取得に失敗しました（$maxRetry 回リトライ後）" -ForegroundColor Red
}


# ----------------------------------------------
# デプロイ
# ----------------------------------------------
Write-Host "`n🚀 デプロイを開始します（環境: $env / プロジェクト: $projectId）..." -ForegroundColor Cyan
# ✅ Firebase Functions のデプロイ実行（projectId 明示）
& firebase deploy --only functions --project=$projectId --force


# ----------------------------------------------
# デプロイ失敗時に gcf-artifacts を削除する
# ----------------------------------------------
if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Firebase Functions のデプロイに失敗しました" -ForegroundColor Red
  Write-Host "`n🧨 課金対象を削除します" -ForegroundColor Red
  powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env $env
  Write-Host "✅ 課金対象を削除しました" -ForegroundColor Cyan
  exit 1

} else {
  Write-Host "✅ Firebase Functions のデプロイに成功しました" -ForegroundColor Green
}


# ----------------------------------------------
# デプロイ成功時に、デプロイが安定するまで120秒待つ(普通安定まで60～90秒)
# ----------------------------------------------
Write-Host "`n🕒 gcf-artifacts などの残骸ファイルを削除する前に120秒待ちます(デプロイ完了が安定するまで)" -ForegroundColor Yellow
Write-Host "⏳ 中止したい場合は [Ctrl + C] を押してください(残骸ファイルは削除されません)..." -ForegroundColor Yellow

for ($i = 120; $i -ge 1; $i--) {
  Write-Host -NoNewline "`r残り $i 秒..."
  Start-Sleep -Seconds 1
} 


# ----------------------------------------------
# 課金対象を削除
# ----------------------------------------------
Write-Host "`n🧹 GCFバケットと Artifact Registry などのクリーンアップを実行します..." -ForegroundColor Cyan
Write-Host   "🧹 Cloud Build / PubSub の課金源も削除/抑制します..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env $env

Write-Host "`n✅ デプロイ & クリーンアップ完了！" -ForegroundColor Green


# ----------------------------------------------
# 課金対象一覧(HTML)をブラウザで開き、確認を促す
# ----------------------------------------------
$reportPath = "pause_firebase_check.html"
if (Test-Path $reportPath) {
    Start-Process $reportPath
    Write-Host "`n🔴 「pause_firebase 休眠チェック用リンク($reportPath)」をブラウザで開きました" -ForegroundColor Red 
    Write-Host "🔴 知らない間に課金されてないかしっかりチェックしてください" -ForegroundColor Red 

} else {
    Write-Host "⚠️ $reportPath が見つかりませんでした。" -ForegroundColor Yellow
}

