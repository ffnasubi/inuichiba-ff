param(
    [string]$env = "ffdev",         # ← ここで "ffprod" または "ffdev" を指定（既定値は ffdev）
    [switch]$deleteOldVersions      # ← 古いバージョンを削除するかどうか（--deleteOldVersions）
)

# PowerShell スクリプト: .env.set_secrets.ps1
# .env.secrets.ffprod.txt/.env.secrets.ffdev.txt を読み込んで Firebase Secrets に一括登録
# .ps1のファイル形式は UTF-8(BOM付き) であること
# 実行方法(管理者権限で)
# cd "D:\nasubi\inuichiba_ff"
# 開発環境(ffdev)に Secrets を登録（既定値）
powershell -ExecutionPolicy Bypass -File .env.set_secrets.ps1
# 本番環境(ffprod)に登録
powershell -ExecutionPolicy Bypass -File .env.set_secrets.ps1 -env ffprod
# 本番環境で古いバージョンも削除
powershell -ExecutionPolicy Bypass -File .env.set_secrets.ps1 -env ffprod -deleteOldVersions


# 環境ごとの設定
if ($env -eq "ffprod") {
    $projectId = "inuichiba-ffprod"
    $envFile = ".\.env.secrets.ffprod.txt"
    $secretSuffix = "_PROD"
} elseif ($env -eq "ffdev") {
    $projectId = "inuichiba-ffdev"
    $envFile = ".\.env.secrets.ffdev.txt"
    $secretSuffix = "_DEV"
} else {
    Write-Error "❌ 不明な環境 [$env] が指定されました。'ffdev' または 'ffprod' を指定してください。" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $envFile)) {
    Write-Error "❌ 指定されたファイル [$envFile] が見つかりません。スクリプトを終了します。" -ForegroundColor Red
    exit 1
}

Write-Output "🔄 Secrets を [$env] 環境（$projectId）に登録します。" -ForegroundColor Green
Write-Output "📄 対象ファイル: $envFile" -ForegroundColor Green

Get-Content $envFile | ForEach-Object {
    if ($_ -match "^\s*$" -or $_ -match "^\s*#") { return }

    $parts = $_ -split '=', 2
    if ($parts.Count -ne 2) {
        Write-Warning "⚠️ 無効な行: $_"  -ForegroundColor Yellow
        return
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()

    $exists = & gcloud secrets describe $key --project=$projectId 2>$null
    if (!$?) {
        Write-Output "🆕 Secret [$key] を新規作成中..."  -ForegroundColor -ForegroundColor DarkCyan
        & gcloud secrets create $key --replication-policy="automatic" --project=$projectId
    } else {
        Write-Output "🔁 Secret [$key] は既に存在します。バージョンを追加します。" -ForegroundColor DarkCyan
    }

    $tmp = New-TemporaryFile
    $cleanValue = $value -replace '^[\uFEFF\u200B]', ''
    $cleanValue = $cleanValue -replace '[\x00-\x1F]', ''
    Set-Content -Path $tmp -Value $cleanValue -NoNewline -Encoding UTF8

    & gcloud secrets versions add $key --data-file=$tmp --project=$projectId
    Remove-Item $tmp

    if ($deleteOldVersions) {
        $versions = & gcloud secrets versions list $key --project=$projectId --format="value(name)"
        $latest = & gcloud secrets versions list $key --project=$projectId --sort-by="~createTime" --limit=1 --format="value(name)"
        foreach ($ver in $versions) {
            if ($ver -ne $latest) {
                Write-Output "🗑 古いバージョン [$ver] を削除します..." -ForegroundColor Cyan
                & gcloud secrets versions destroy $ver --secret=$key --project=$projectId
            }
        }
    }
}

Write-Output "`n🧪 各 Secret の最新有効バージョン:" -ForegroundColor Green
$secretNames = @(
    "CHANNEL_ACCESS_TOKEN$secretSuffix",
    "CHANNEL_SECRET$secretSuffix",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY$secretSuffix",
    "SUPABASE_TABLE_NAME$secretSuffix",
    "MY_LINE_USER_ID"
)

foreach ($name in $secretNames) {
    Write-Output ""
    Write-Output "🔑 $name:"  -ForegroundColor DarkCyan
    $cmd = "gcloud secrets versions list $name --filter=`"state=enabled`" --sort-by=`"~createTime`" --limit=1 --project=$projectId --format=`"table(name, state, createTime)`""
    Invoke-Expression $cmd
}

Write-Output "`n🛡 脆弱性スキャンを無効化中..." -ForegroundColor Cyan
& gcloud artifacts repositories update gcf-artifacts `
    --location=asia-northeast1 `
    --clear-description `
    --update-labels=containeranalysis.googleapis.com/scan-on-push=disabled `
    --project=$projectId

Write-Output "`n🏁 完了：すべての Secrets 処理を実行しました！"  -ForegroundColor Green
Write-Output "✅ Secrets 登録完了しました！" -ForegroundColor Green
