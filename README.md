# inuichiba
LINE bot for Inuichiba
# redeploy trigger
 
📝 プロジェクト構成とファイル命名ルール（inuichiba_ff）

このドキュメントは、プロジェクト inuichiba_ff のローカル構成と命名規則、運用ルールを整理したものです。将来の自分のために書いています。

📁 ディレクトリ構成（主要）

inuichiba_ff/
├── functions/               # Firebase Functions 本体
├── public/                 # Firebase Hosting 公開用ディレクトリ（画像など）
├── .backup/                # 自動・手動バックアップ格納用
├── .github/                # GitHub Actions用設定
├── .gitignore              # Git管理除外ファイル定義
├── firebase.json           # Firebase設定
├── .firebaserc             # プロジェクト切り替え設定
├── eslint.config.js        # ESLint設定（使用中！）

📂 環境変数とSecretsファイル

🔐 .env.secrets.*.txt

ファイル名

用途

.env.secrets.ffdev.txt

ffdev環境のSecrets一括定義

.env.secrets.ffprod.txt

ffprod環境のSecrets一括定義

※ Secrets は Git 管理されないよう .gitignore で除外済み。

⚙️ スクリプト類（PowerShell）

📌 Secrets設定用

ファイル名

説明

env.set_secrets.ps1

-ProjectId に応じてSecretsを設定（本番/開発共通）

※ ファイル名は .env. 付きで残しているが、明確さ優先で env.set_secrets.deploy.ps1 にリネーム検討中。

📌 Artifact Registry 初期化用

ファイル名

対象環境

説明

reset-artifactregistry.ffdev.ps1

ffdev

Firebase Functions用の初期化スクリプト（色つき＆コメント満載）

reset-artifactregistry.ffprod.ps1

ffprod

同上、ffprod版

⏳ reset-artifactregistry 実行ポリシー

通常の firebase deploy では実行不要

以下のような場合のみ使用：

GCF deploy エラー（Precondition failed など）

Artifact Registry 構成の初期化／再作成が必要なとき

運用が安定していれば、月1程度の定期実行でも十分

🔑 鍵ファイル（Service Account JSON）

ファイル名

説明

deployer.ffdev.json

ffdev用 GitHub Action / PS用認証キー（1個のみ）

deployer.ffprod.json

ffprod用 同上

※ 使うのは各環境で1つだけ。他の鍵（adminsdk, appspotなど）は削除済。

✅ 命名ルールの基本方針

.env. → Secretsや設定ファイル（中身が環境変数系）

reset- → 環境の初期化系

deployer.*.json → 環境ごとの認証用SA鍵

環境名（ffdev, ffprod）はファイル末尾につけて区別

.ps1 はWindows専用、ローカル用

🧹 その他

policy-backup.ffprod.json は Supabase RLSポリシーなどのバックアップ

fldummy.txt はVSCodeの空ディレクトリ防止用

🗒️ 今後の予定（メモ）

env.set_secrets.ps1 → env.set_secrets.deploy.ps1 にリネームするか？

Mac/Linux 開発者が増えたら .sh 版も作成予定

.README.md は自分しか読まなくてもちゃんと書く（未来の自分のため）




