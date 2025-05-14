# powershell -ExecutionPolicy Bypass -File .\reset-iam-ffprod.ps1
# ===============================================
# ffprod IAM ロール最小化スクリプト
# Cloud Build Builder のみ付与し、他のロールは削除
# ===============================================

$projectId = "inuichiba-ffprod"
$saEmail = "$projectId@appspot.gserviceaccount.com"

Write-Host "⚠️ プロジェクト: $projectId"
Write-Host "⚠️ サービスアカウント: $saEmail"
Write-Host "⚠️ 既存 IAM ロールを確認中..." -ForegroundColor Cyan

# 現在のロール取得
$bindings = gcloud projects get-iam-policy $projectId --flatten="bindings[].members" --filter="bindings.members:$saEmail" --format="table(bindings.role)" | Select-String "roles/"
$bindings = $bindings -replace "\s+",""  # トリム

Write-Host "🔍 現在のロール一覧:"
$bindings | ForEach-Object { Write-Host " - $_" }

# 必要なロール
$requiredRole = "roles/cloudbuild.builds.builder"

# 不要なロールだけ抽出
$rolesToRemove = @()
foreach ($role in $bindings) {
    if ($role -ne $requiredRole) {
        $rolesToRemove += $role
    }
}

# 確認
if ($rolesToRemove.Count -eq 0) {
    Write-Host "✅ 既に最小構成（$requiredRole のみ）です！" -ForegroundColor Green
} else {
    Write-Host "🚨 以下の不要ロールを削除します:"
    $rolesToRemove | ForEach-Object { Write-Host " - $_" }

    foreach ($role in $rolesToRemove) {
        Write-Host "➖ 削除: $role"
        gcloud projects remove-iam-policy-binding $projectId --member="serviceAccount:$saEmail" --role="$role" --quiet
    }
}

# 必要なロール再確認・再付与
Write-Host "🔒 必要なロールを再確認・再付与: $requiredRole"
gcloud projects add-iam-policy-binding $projectId --member="serviceAccount:$saEmail" --role="$requiredRole" --quiet

Write-Host "🌟 完了: $projectId は roles/cloudbuild.builds.builder のみになりました。" -ForegroundColor Green
