// env-loader.js（本番環境用）

/**
 * 本番バッチ用の環境変数ローダー
 * `.env.secrets.ffprod.txt` を読み込み、本番用トークン等を process.env にセットします。
 */
const dotenv = require("dotenv");
const path = require("path");

const envPath = path.resolve(__dirname, "../../.env.secrets.ffprod.txt");

const result = dotenv.config({ path: envPath });

if (result.error) {
  console.error("❌ 本番用 .env 読み込み失敗:", result.error);
} else {
  console.log("✅ 本番用 .env 読み込み成功（リッチメニュー用）");
}


  