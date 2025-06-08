<#
deployer-create-service-account.ps1
.SYNOPSIS
Firebase Functions デプロイ用サービスアカウントを作成または確認し、必要なIAMロールを付与。
鍵を安全に再生成。

.DESCRIPTION
- ffdev / ffprod 用の SA を作成（または確認）
- 既存の鍵は削除
- 新しい鍵を deployer.{env}.json として保存
- IAMロールを付与

.PARAMETER env
ffdev または ffprod（既定値は ffdev）

.EXECUTION EXAMPLE
cd d:\nasubi\inuichiba_ff
#ffprod
powershell -ExecutionPolicy Bypass -File .\deployer-create-service-account.ps1 -env ffprod
#ffdev
powershell -ExecutionPolicy Bypass -File .\deployer-create-service-account.ps1 -env ffdev

.NOTES
- この鍵ファイルは Git 管理外にしてください（.gitignore）
- ロールは Cloud Functions + Firebase + Cloud Build に必要な最小構成のみ
- 鍵漏洩対策のため定期的に rotate 推奨(最低でも月1回、重要なら1日1回も可)
- 鍵を再作成したら、GitHubの Secrets and variables > Actions > Repository secretsに
  FIREBASE_SERVICE_ACCOUNT_INUICHIBA_FF* と言う名前で、json(鍵)の中身を登録し直すこと
- Secret Manager を使わない構成（課金ゼロ構成対応）
#>

# ─────────────────────────────
# 🔐 サービスアカウント鍵 (deployer.ff*.json) 運用ルール
# ─────────────────────────────
#
# ✅ 鍵(JSON)は通常、以下の場合のみ再発行が必要
# 
#   1. サービスアカウント自体を削除→再作成したとき
#   2. 鍵の漏洩や不正アクセスの疑いが発生したとき
#   3. 組織のポリシーで定期ローテーションが義務付けられている場合
#   結局2の対策で、定期的にローテーション推奨でしょう(3にもつながる) 
#
# ✅ 以下の場合は再発行不要
#
#   - gcf-artifactsリポジトリを削除・再作成しただけ
#
# ✅ 安全運用のための推奨事項
#
#   - 鍵ファイル(.json)は絶対にGitリポジトリに含めない (.gitignore必須)
#   - 鍵の使用範囲は最小限に（できるだけローカル作業に限定）
#   - 使用が終わったら `$env:GOOGLE_APPLICATION_CREDENTIALS` をクリア
#     （例: `$env:GOOGLE_APPLICATION_CREDENTIALS=""`）
#
# ─────────────────────────────


param (
  [ValidateSet("ffdev","ffprod")]
  [string]$env="ffdev"
)

# ─────────────────────────────
# 初期設定
# ─────────────────────────────
$projectId = "inuichiba-$env"
$saName = "$env-inuichiba-deployer"
$saEmail = "$saName@$projectId.iam.gserviceaccount.com"
$outputJson = "deployer.$env.json"

Write-Host "🔍 対象プロジェクト: $projectId" -ForegroundColor Cyan
Write-Host "🔍 サービスアカウント: $saEmail" -ForegroundColor Cyan

# ─────────────────────────────
# 認証チェック
# ─────────────────────────────
$currentAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)"
if (-not $currentAccount) {
  Write-Host "❌ gcloud CLI にログインしていません。まず `gcloud auth login` を実行してください。" -ForegroundColor Red
  exit 1
}

# ─────────────────────────────
# サービスアカウントの作成確認
# ─────────────────────────────
$saList = gcloud iam service-accounts list --project=$projectId --format="value(email)"
$exists = $saList | Where-Object { $_ -eq $saEmail }
if ($exists) {
  Write-Host "✅ サービスアカウントは既に存在します。" -ForegroundColor Green
} else {
  Write-Host "🆕 サービスアカウントを作成します..." -ForegroundColor Yellow
  gcloud iam service-accounts create $saName `
    --display-name="Firebase Deploy Service Account ($env)" `
    --project=$projectId
}

# ─────────────────────────────
# IAMロール付与（必要最小限）
# ─────────────────────────────
$roles = @(
  "roles/cloudfunctions.developer",
  "roles/firebase.admin",
  "roles/cloudbuild.builds.editor",
  "roles/iam.serviceAccountUser"
)

foreach ($role in $roles) {
  Write-Host "🔐 IAMロール付与: $role"
  gcloud projects add-iam-policy-binding $projectId `
    --member="serviceAccount:$saEmail" `
    --role=$role `
    --quiet
}

# ─────────────────────────────
# 古い鍵を削除（全削除）
# ─────────────────────────────
Write-Host "🧹 古い鍵を削除中..." -ForegroundColor Yellow
$keyNames = gcloud iam service-accounts keys list `
  --iam-account=$saEmail `
  --project=$projectId `
  --format="value(name)"

$keyIds = $keyNames | ForEach-Object {
  ($_ -split "/")[-1]
}

foreach ($keyId in $ketIds) {
  Write-Host "   🗑️ 削除: $keyId"
  gcloud iam service-accounts keys delete $keyId `
    --iam-account=$saEmail `
    --project=$projectId `
    --quiet
}

# ─────────────────────────────
# 新しい鍵を生成
# ─────────────────────────────
Write-Host "🔐 新しい鍵を生成中..." -ForegroundColor Cyan
gcloud iam service-accounts keys create "$outputJson" `
  --iam-account=$saEmail `
  --project=$projectId

Write-Host "`n✅ 完了: $outputJson を生成しました" -ForegroundColor Green
Write-Host "📌 GitHub Secrets に以下の名前でこの JSON(鍵) の中身を登録しなおしてください" -ForegroundColor Cyan
Write-Host "   GitHub Secret名: FIREBASE_SERVICE_ACCOUNT_INUICHIBA_$($env.ToUpper())" -ForegroundColor Cyan
Write-Host "🛡 使用後は `$env:GOOGLE_APPLICATION_CREDENTIALS = `"$PWD\$outputJson`"" -ForegroundColor Gray
