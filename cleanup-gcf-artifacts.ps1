# ⚠ FF本番用 GCF Artifact の古いオブジェクトを一括削除
# 実行方法:
# .\cleanup-gcf-artifacts.ps1 -env ffprod
# .\cleanup-gcf-artifacts.ps1 -env ffdev


param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("ffprod", "ffdev")]
    [string]$env
)

if ($env -eq "ffprod") {
    $projectNumber = "757611015224"
} elseif ($env -eq "ffdev") {
    $projectNumber = "412413670174"
}

$bucketName = "gcf-v2-sources-$projectNumber-asia-northeast1"

Write-Host "`n🚨 [$env] FF Artifact バケット内の古いファイルを全削除します。バケット自体は残します。" -ForegroundColor Yellow
Write-Host "  バケット: $bucketName" -ForegroundColor Cyan

# ファイル一覧取得
$files = & gcloud storage ls gs://$bucketName

if ($files.Count -eq 0) {
    Write-Host "`n✅ バケット内はすでに空です。" -ForegroundColor Green
    exit 0
}

# 削除確認
Write-Host "`n📂 以下のファイルを削除します:"
$files | ForEach-Object { Write-Host " - $_" }

$confirm = Read-Host "`n本当に削除しますか？ (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "`n❌ キャンセルしました。" -ForegroundColor Red
    exit 1
}

# 削除実行
& gcloud storage rm gs://$bucketName/**

Write-Host "`n🎉 完了しました。" -ForegroundColor Green
