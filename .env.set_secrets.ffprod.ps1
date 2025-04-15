# PowerShell スクリプト: .env.set_secrets.ffprod.ps1
# .env.secrets.ffprod.txt を読み込んで Firebase Secrets に一括登録
# ファイル形式は UTF-8(BOM付き) であること

# 実行方法
# cd "D:\nasubi\inuichiba_ff"
# powershell -ExecutionPolicy Bypass -File .env.set_secrets.ffprod.ps1
# 注意！古いバージョンを自動削除付きで実行するとき(削除時に確認はされるけどね)
# cd "D:\nasubi\inuichiba_ff"
# powershell -ExecutionPolicy Bypass -File .env.set_secrets.ffprod.ps1 --delete-old


# プロジェクトID（必要に応じて変更）
$projectId = "inuichiba-ffprod"

# .env ファイルの読み込み
$envFile = ".\.env.secrets.ffprod.txt"
if (!(Test-Path $envFile)) {
    Write-Error "❌ .env.secrets.ffprod.txt が見つかりません。スクリプトを終了します。"
    exit 1
}

# 行ごとに読み込む
Get-Content $envFile | ForEach-Object {
    # 空行とコメント行をスキップ
    if ($_ -match "^\s*$" -or $_ -match "^\s*#") {
        return
    }

    # キーと値を分割
    $parts = $_ -split '=', 2
    if ($parts.Count -ne 2) {
        Write-Warning "⚠️ 無効な行: $_"
        return
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()

    # Secret を作成（すでに存在する場合は無視）
    $exists = & gcloud secrets describe $key --project=$projectId 2>$null
    if (!$?) {
        Write-Output "🆕 Secret [$key] を新規作成中..."
        & gcloud secrets create $key --replication-policy="automatic" --project=$projectId
    } else {
        Write-Output "🔁 Secret [$key] は既に存在します。バージョンを追加します。"
    }

    # 値を一時ファイルに保存
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $value -NoNewline -Encoding UTF8


    # バージョン追加
    & gcloud secrets versions add $key --data-file=$tmp --project=$projectId
    Remove-Item $tmp

    
    # 🧹 古いバージョンの削除（最新以外を削除）
    $versions = & gcloud secrets versions list $key --project=$projectId --format="value(name)"
    $latest = & gcloud secrets versions list $key --project=$projectId --sort-by="~createTime" --limit=1 --format="value(name)"
    
    foreach ($ver in $versions) {
        if ($ver -ne $latest) {
            Write-Output "🗑 古いバージョン [$ver] を削除します..."
            & gcloud secrets versions destroy $ver --secret=$key --project=$projectId
        }
    }

}

# 最終確認として、登録済み Secrets を一覧表示
Write-Output "`n📋 現在の Secrets 一覧:"
& gcloud secrets list --project=$projectId

# 🔍 各 Secret の現在の「有効バージョン」を確認（念のため確認したい場合）
# 🔄 最新バージョンのみを確認できます（登録直後の確認にも便利）

Write-Output "`n🧪 各 Secret の最新有効バージョン:"
$secretNames = @(
    "CHANNEL_ACCESS_TOKEN_PROD",
    "CHANNEL_SECRET_PROD",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY_PROD",
    "SUPABASE_TABLE_NAME_PROD",
    "MY_LINE_USER_ID"
)

foreach ($name in $secretNames) {
    Write-Output "`n🔑 $name:"
    & gcloud secrets versions list $name `
        --filter="state=enabled" `
        --sort-by="~createTime" `
        --limit=1 `
        --project=$projectId `
        --format="table(name, state, createTime)"
}

Write-Output "`n🏁 完了：バージョン一覧の確認も含めてすべて実行しました！"


Write-Output "✅ Secrets 登録完了しました！"

