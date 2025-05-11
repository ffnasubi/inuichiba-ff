# Firebase Functions 復旧手順

## 💡 目的
一時休眠していた Firebase Functions（webhook）を復元し、再び稼働できる状態に戻します。

---

## ✅ 前提

- このスクリプトは `inuichiba-ffprod` / `inuichiba-ffdev` 両方を対象にしています
- Firebase CLI / gcloud CLI はすでにインストール済みであること
- `firebase.ffprod.json` / `firebase.ffdev.json` がプロジェクト内にあること

---

## 🔧 実行手順（Windows）

```powershell
cd D:\nasubi\inuichiba_ff
powershell -ExecutionPolicy Bypass -File .\wake-firebase.ps1

---

🛠 トラブルシューティング
firebase login または gcloud auth login が切れていたら再ログインしてください
functions:deploy 時に node_modules 関連エラーが出る場合、npm install を先に行ってください
