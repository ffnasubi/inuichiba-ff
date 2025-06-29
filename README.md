# inuichiba
LINE bot for Inuichiba
# redeploy trigger
 
📝 プロジェクト構�Eとファイル命名ルール�E�Enuichiba_ff�E�E
こ�Eドキュメント�E、�EロジェクチEinuichiba_ff のローカル構�Eと命名規則、E��用ルールを整琁E��たものです。封E��の自刁E�Eために書ぁE��ぁE��す、E
📁 チE��レクトリ構�E�E�主要E��E
inuichiba_ff/
├── functions/              # Firebase Functions 本佁E├── public/                 # Firebase Hosting 公開用チE��レクトリ�E�画像など�E�E├── .backup/                # 自動�E手動バックアチE�E格納用
├── .github/                # GitHub Actions用設宁E├── .gitignore              # Git管琁E��外ファイル定義
├── firebase.*.json         # Firebase設宁E├── eslint.config.js        # ESLint設定（使用中�E�E��E
📂 環墁E��数とSecretsファイル

🔐 .env.secrets.*.txt

ファイル吁E
用送E
.env.secrets.ffdev.txt

ffdev環墁E�ESecrets一括定義

.env.secrets.ffprod.txt

ffprod環墁E�ESecrets一括定義

※ Secrets は Git 管琁E��れなぁE��ぁE.gitignore で除外済み、E
⚙︁Eスクリプト類！EowerShell�E�E
📌 Secrets設定用

ファイル吁E
説昁E
env.set_secrets.ps1

-ProjectId に応じてSecretsを設定（本番/開発共通！E
※ ファイル名�E .env. 付きで残してぁE��が、�E確さ優先で env.set_secrets.deploy.ps1 にリネ�Eム検討中、E
📌 Artifact Registry 初期化用

ファイル吁E
対象環墁E
説昁E
reset-artifactregistry.ffdev.ps1

ffdev

Firebase Functions用の初期化スクリプト�E�色つき！E��メント満載！E
reset-artifactregistry.ffprod.ps1

ffprod

同上、ffprod牁E
⏳ reset-artifactregistry 実行�Eリシー

通常の firebase deploy では実行不要E
以下�Eような場合�Eみ使用�E�E
GCF deploy エラー�E�Erecondition failed など�E�E
Artifact Registry 構�Eの初期化／�E作�Eが忁E��なとぁE
運用が安定してぁE��ば、月1程度の定期実行でも十刁E
🔑 鍵ファイル�E�Eervice Account.json�E�E
ファイル吁E
説昁E
deployer.ffdev.json

ffdev用 GitHub Action / PS用認証キー�E�E個�Eみ�E�E
deployer.ffprod.json

ffprod用 同丁E
※ 使ぁE�Eは吁E��墁E��1つだけ。他�E鍵�E�Edminsdk, appspotなど�E��E削除済、E
✁E命名ルールの基本方釁E
.env. ↁESecretsめE��定ファイル�E�中身が環墁E��数系�E�E
reset- ↁE環墁E�E初期化系

deployer.*.json ↁE環墁E��との認証用SA鍵

環墁E���E�Efdev, ffprod�E��Eファイル末尾につけて区別

.ps1 はWindows専用、ローカル用

🧹 そ�E仁E
policy-backup.ffprod.json は Supabase RLSポリシーなどのバックアチE�E

fldummy.txt はVSCodeの空チE��レクトリ防止用

🗒�E�E今後�E予定（メモ�E�E
env.set_secrets.ps1 ↁEenv.set_secrets.deploy.ps1 にリネ�Eムするか！E
Mac/Linux 開発老E��増えたら .sh 版も作�E予宁E
.README.md は自刁E��か読まなくてもちめE��と書く（未来の自刁E�Eため�E�E


🌟PROD/DEVをFFPROD/FFDEVへ統一する
# ✅ 目的：Secretsの接尾辞を FFPROD / FFDEV に統一し、過去の DEV / PROD を廃止する
# ✅ 修正対象：
# - .env.secrets.ffprod.txt / .env.secrets.ffdev.txt（修正済）
# - .env.set_firebase_config.ps1（以下に修正内容あり）
# - deploy-and-cleanup.ps1（Firebase Config登録部分に1行修正）
# - env.js（envSuffixを isProd ? 'ffprod' : 'ffdev' に固定）
# 🔹 deploy.yml は起動後に対応

✅ 修正対象（対応完了 or 修正予定）
ファイル名	対応内容	状態
.env.secrets.ff*.txt            FFPROD / FFDEV に統一済	                ✅ 完了
.env.set_firebase_config.ps1	$envSuffix = "FFDEV" に修正	            🔧 対応中
deploy-and-cleanup.ps1	        Firebase Config 登録処理の接尾辞を統一	    🔧 対応中
env.js	                        envSuffix = isProd ? "ffprod" : "ffdev" で読み出し	🔧 対応中
.env.set_secrets-gh.ps1	        対象外（GitHub向け）	                    🚫 保留
deploy.yml	                    GitHub Actionsにて後日対応	            ⏳ 後回し
