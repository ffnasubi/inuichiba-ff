// lib/env.js
// Firebase Functions 向けの環境変数設定ファイル
// 変数定義 → 条件分岐 → ログ出力の順に記述することで、未初期化エラーを防ぎます(厳守)！

// Firebase の Secrets で定義された NODE_ENV を process.env に代入
if (!process.env.NODE_ENV && process.env['NODE_ENV']) {
  process.env.NODE_ENV = process.env['NODE_ENV'];
}

// Node.jsに.env.*を開発環境に応じて読み込ませる
const dotenv = require('dotenv');

const path = require("path");

// 1. 環境ファイルの読み込み（ローカル用）
// Firebase Functions では自動的に環境変数が読み込まれるため、
// この読み込みはローカル開発時のみ必要
const envPath = process.env.NODE_ENV === "production"
  ? ".env.ffprod"
  : ".env.ffdev";

const result = dotenv.config({ path: path.resolve(__dirname, "..", envPath) });

if (result.error) {
  console.error("❌ .env ファイルの読み込みに失敗しました:", result.error);
}

// 2. 環境モードの判定
// Firebase では Vercel のような preview モードは存在しません
// NODE_ENV によって production / development を判定します
const rawEnv = process.env.NODE_ENV ?? 'development';


// 3. 環境フラグ
const isProd = rawEnv === "production";
const isDev = rawEnv === "development";
const isPreview = false; // Firebase Functionsではpreview概念は存在しない


// 4. 環境に依存する設定値（もうここではisProdを使ってOK）
// 本番環境と開発環境とに応じて切り分ける
const channelAccessToken = isProd
  ? process.env.CHANNEL_ACCESS_TOKEN_PROD
  : process.env.CHANNEL_ACCESS_TOKEN_DEV;

const channelSecret = isProd
  ? process.env.CHANNEL_SECRET_PROD
  : process.env.CHANNEL_SECRET_DEV;

// 使用する Supabase テーブル名を、環境によって切り替える
const usersTable = isProd
  ? process.env.SUPABASE_TABLE_NAME_PROD
  : process.env.SUPABASE_TABLE_NAME_DEV;

const supabaseKey = isProd
  ? process.env.SUPABASE_SERVICE_ROLE_KEY_PROD
  : process.env.SUPABASE_SERVICE_ROLE_KEY_DEV;

const supabaseUrl = process.env.SUPABASE_URL;

// LINE Bot管理者用のユーザーID。Supabaseに書き込む時のuserId。確認にひとつは必須
const myLineUserId = process.env.MY_LINE_USER_ID;

// コンテンツのホスティングURL（画像とカルーセルメッセージのベースパス）
const baseDir = isProd
  ? "https://inuichiba-ffprod.web.app/"
  : "https://inuichiba-ffdev.web.app/";

// メニュー名：メニューキャッシュクリアや更新確認に使用
// ローカルテスト用で現在未使用。.env.*のみ一応定義。
const targetMenuName = process.env.TARGET_MENU_NAME;

// 5. 環境名の最後の定義(ログ出力)
// ✅ 最後に定義！ ← これが正解
// (まだ envName が未初期化の状態で使われてしまうとクラッシュする)
const envName = rawEnv;

// ✅ ログ出力（使うのは最後の最後！）
// console.log() は定義後に！それ以前に使うと未初期化になる
console.log("✅ NODE_ENV:", process.env.NODE_ENV);
console.log("✅ 環境判定された envName:", envName);
console.log("✅ isProd:", isProd);
console.log("📦 Supabase Table(usersTable):", usersTable);


if (!isProd) {
  console.log("🐾 環境判定された envName:", envName);
  console.log("🐾 isProd:", isProd);
	console.log("🔐 channelSecret:", channelSecret);
  if (channelAccessToken) {
    console.log("🔐 channelAccessTokenの長さ:", channelAccessToken.length);
    console.log("🔐 channelAccessTokenの先頭数文字:", channelAccessToken.slice(0, 5) + "...");
  } else {
    console.log("⚠️ channelAccessToken が未定義または空です");
  }
	console.log("📦 Supabase URL:", supabaseUrl);
  console.log("📦 Supabase Table(usersTable):", usersTable);
  console.log("📦 supabaseKey:", supabaseKey ? "✅ OK" : "❌ NG");
}

// エクスポート（CommonJS形式）
module.exports = {
  envName,
  isProd,
  isDev,
  isPreview,
  channelAccessToken,
  channelSecret,
  supabaseKey,
  supabaseUrl,
  usersTable,
  myLineUserId,
  baseDir,
  targetMenuName,
};

