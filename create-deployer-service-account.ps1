# create-deployer-service-account.ps1
<#[
.SYNOPSIS
  Firebase Functions デプロイ用のサービスアカウントを自動確認・作成・鍵発行するスクリプト

.DESCRIPTION
  - ffdev または ffprod 用のサービスアカウントを確認または作成
  - 既存の鍵を自動取得し、すべて削除（安全な一括削除）
  - 新しい鍵を JSON 形式でルートに保存
  - サービスアカウントに roles/editor を自動付与
  - 生成された JSON は reset-artifactregistry.ps1 や firebase deploy に使用可能

.PARAMETER env
  対象環境。"ffdev" または "ffprod" のいずれか。
  省略時は "ffdev"。
  # ffdev用
  .\create-deployer-service-account.ps1
  # ffprod用
  .\create-deployer-service-account.ps1 -env ffprod

.NOTES
  実行者には以下の IAM 権限が必要：
    - roles/iam.serviceAccountAdmin           サービスアカウントの作成・管理
    - roles/iam.serviceAccountKeyAdmin        鍵の作成・削除
    - roles/resourcemanager.projectIamAdmin   他のメンバーへのロール付与（必要に応じて）
  🔐 オーナー（Owner）権限がこれらを内包している場合もありますが、
     明示的にロールを持つことが推奨されます。
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
#
# ✅ 以下の場合は再発行不要
#
#   - gcf-artifactsリポジトリを削除・再作成しただけ
#   - Firebaseプロジェクト側で設定変更しただけ
#
# ✅ 安全運用のための推奨事項
#
#   - 鍵ファイル(.json)は絶対にGitリポジトリに含めない (.gitignore必須)
#   - 鍵の使用範囲は最小限に（できるだけローカル作業に限定）
#   - 使用が終わったら `$env:GOOGLE_APPLICATION_CREDENTIALS` をクリア
#     （例: `$env:GOOGLE_APPLICATION_CREDENTIALS=""`）
#
# ✅ もし再発行が必要になった場合の手順
#
#   1. 古い鍵をGCPコンソールまたはスクリプトで削除
#   2. 新しい鍵を作成し、ルートに保存（例: deployer.ffdev.json）
#   3. `$env:GOOGLE_APPLICATION_CREDENTIALS` を新しいファイルに設定
#   4. テストデプロイで動作確認
#
# ─────────────────────────────


param (
  [ValidateSet("ffdev", "ffprod")]
  [string]$env = "ffdev"
)

# 定数定義
$projectId = "inuichiba-$env"
$saName = "$env-inuichiba-deployer"
$saEmail = "$saName@$projectId.iam.gserviceaccount.com"
$outputJson = "deployer.$env.json"

Write-Host "🔍 プロジェクト: $projectId" -ForegroundColor Cyan
Write-Host "🔍 サービスアカウント: $saEmail" -ForegroundColor Cyan

# サービスアカウント存在確認
$exists = gcloud iam service-accounts list --project=$projectId --format="value(email)" | Select-String $saEmail
if (-not $exists) {
  Write-Host "🆕 サービスアカウントを新規作成中..." -ForegroundColor Yellow
  gcloud iam service-accounts create $saName `
    --display-name="Firebase Deploy Service Account" `
    --project=$projectId
} else {
  Write-Host "✅ サービスアカウントは既に存在します。" -ForegroundColor Green
}

# roles/editor をプロジェクトレベルで付与
Write-Host "🔐 サービスアカウントに roles/editor を付与中..." -ForegroundColor Cyan

gcloud projects add-iam-policy-binding $projectId `
  --member="serviceAccount:$saEmail" `
  --role="roles/editor"

# 既存の鍵の削除（すべて）
Write-Host "🧹 既存の鍵を取得して削除中（使用中の鍵はスキップ）..." -ForegroundColor Yellow
$keyIds = gcloud iam service-accounts keys list `
  --iam-account=$saEmail `
  --project=$projectId `
  --format="value(name.basename())"

foreach ($keyId in $keyIds) {
  Write-Host "   🔻 削除: $keyId" -ForegroundColor DarkYellow
  try {
    gcloud iam service-accounts keys delete $keyId `
      --iam-account=$saEmail `
      --project=$projectId `
      --quiet
  } catch {
    Write-Host "   ⚠️ 削除スキップ（使用中/ロック中の可能性あり）: $keyId" -ForegroundColor Magenta
  }
}

# 新しい鍵の作成
Write-Host "🔐 新しい鍵を作成し、$outputJson に保存中..." -ForegroundColor Cyan

gcloud iam service-accounts keys create "$outputJson" `
  --iam-account=$saEmail `
  --project=$projectId

# 完了メッセージ
Write-Host "\n✅ 環境 [$env] 用の共通鍵を作成しました！" -ForegroundColor Yellow
Write-Host "📌 次の環境変数を設定して使用してください(開発環境の場合):" -ForegroundColor Cyan
Write-Host "   `$env:GOOGLE_APPLICATION_CREDENTIALS = \"$PWD\$outputJson\"" -ForegroundColor Green

Write-Host "`n📌 この共通鍵は以下の両方で使用可能です:" -ForegroundColor Cyan
Write-Host "   - Firebase Functions をデプロイする場合（開発環境）:" -ForegroundSColor DarkCyan
Write-Host "       firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force" -ForegroundColor Green
Write-Host "   - gcf-artifacts を削除し IAM ロールを再付与する場合（開発環境）:" -ForegroundColor DarkCyan
Write-Host "       .\reset-artifactregistry.ps1 -projectId ffdev" -ForegroundColor Green