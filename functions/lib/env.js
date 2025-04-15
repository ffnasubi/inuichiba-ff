// lib/env.js
// Firebase Functions 向けの環境変数設定ファイル
// 変数定義 → 条件分岐 → ログ出力の順に記述することで、未初期化エラーを防ぎます(厳守)！

// 1. NODE_ENV の強制反映（Secrets → fallback）
process.env.NODE_ENV = process.env["NODE_ENV"] || "production";

// 初期化エラー調査のための一時的ログ出力(通ったらコメントアウトすること)
// ✅ 🔎 環境判定ログ（Secrets vs .envの切り分けに重要）
console.log("🧪 secretsは本番環境反映済?(process.env.K_SERVICE):", process.env.K_SERVICE || "(not set)");
console.log("🧪 NODE_ENVは本番環境反映済?(process.env.FUNCTION_TARGET):", process.env.FUNCTION_TARGET || "(not set)");
console.log("✅ NODE_ENV(process.env.NODE_ENV):", process.env.NODE_ENV);


// 2. dotenv 読み込み（ローカル開発時のみ）
// Firebase Functions が本番環境かどうかを見分けるチェック
// process.env.K_SERVICE は Cloud Functions Gen2 環境でのみ自動でセットされる(ローカルではセットされない)
// なお本番では dotenv を使わない（Firebase Functionsでは環境変数は Secrets からセットされる）
// なので Firebase Functions 本番環境では dotenv 読み込みをスキップ
// （本番環境を判定するには、Secrets が存在しているかどうか(process.env.K_SERVIC) ではなく、
//   NODE_ENV が定義されているかどうか(process.env.FUNCTION_TARGET) で判断するのが安全、と思ったら
//   どちらの変数もどうもまだ未初期化のようで駄目だった）
// なので安全なローカル判定：NODE_ENV による判断へ変更
// これはSecretsにより注入されるNODE_ENVの値で判定する方法
// Gen2 Functions の Secrets は起動時の env に含まれるため、こちらの方が信頼できる
const isLocal = process.env.NODE_ENV !== "production";

if (isLocal) {
  const dotenv = require('dotenv');
  const path = require("path");

  // Firebase Functions では自動的に環境変数が読み込まれるため、
  // この読み込みはローカル開発時のみ必要(本番用は読み込まない！)
  const envPath = ".env.ffdev";

  const result = dotenv.config({ path: path.resolve(__dirname, "..", envPath) });

  if (result.error) {
    console.error("❌ .env ファイルの読み込みに失敗しました:", result.error);
  } 
}

// 3. 環境モードの判定
// Firebase では Vercel のような preview モードは存在しません
// NODE_ENV によって production / development を判定します
const rawEnv = (process.env.NODE_ENV || 'development').trim().toLowerCase();

// 環境フラグ
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

// 未使用：メニュー名：メニューキャッシュクリアや更新確認に使用(ローカルテスト用)
// .env.*だけに定義を残して他はコメントアウトしてる
// const targetMenuName = process.env.TARGET_MENU_NAME;

// 5. 環境名の最後の定義(ログ出力)
// ✅ 最後に定義！ ← これが正解
// (まだ envName が未初期化の状態で使われてしまうとクラッシュする)
const envName = rawEnv;

// ✅ ログ出力（使うのは最後の最後！）
// console.log() は定義後に！それ以前に使うと未初期化になる

// 本番環境でのデプロイエラーデバッグ用。
// デプロイでのログ出力が正しくが通ったらコメントアウトすること
if (isProd) {
  console.log("✅ NODE_ENV(process.env.NODE_ENV):", process.env.NODE_ENV);
	logSecretSafe("channelSecret(process.env.CHANNEL_SECRET_PROD):", process.env.CHANNEL_SECRET_PROD);
  logSecretSafe("channelAccessToken(process.env.CHANNEL_ACCESS_TOKEN_PROD)", process.env.CHANNEL_ACCESS_TOKEN_PROD);
  console.log("📦 Supabase URL(process.env.SUPABASE_URL):", process.env.SUPABASE_URL);
  console.log("📦 Supabase Table PROD（process.env.SUPABASE_TABLE_NAME_PROD）:", process.env.SUPABASE_TABLE_NAME_PROD || "❌ undefined");
  console.log("📦 Supabase Key PROD（process.env.SUPABASE_SERVICE_ROLE_KEY_PROD読込）:", process.env.SUPABASE_SERVICE_ROLE_KEY_PROD ? "✅ OK" : "❌ NG");
}

if (!isProd) {
  console.log("🐾 環境判定された envName:", envName);
  console.log("🐾 isProd:", isProd);
	logSecretSafe("channelSecret:", channelSecret);
  logSecretSafe("channelAccessToken", channelAccessToken);
  console.log("📦 Supabase URL:", supabaseUrl);
  console.log("📦 Supabase Table(usersTable):", usersTable);
  console.log("📦 supabaseKey:", supabaseKey ? "✅ OK" : "❌ NG");
}

function logSecretSafe(label, value) {
  if (typeof value === "string") {
    if (value.length > 0) {
      console.log(`🔐 ${label} の長さ: ${value.length}`);
      console.log(`🔐 ${label} の先頭5文字: ${value.slice(0, 5)}...`);
    } else {
      console.warn(`⚠️ ${label} は空文字列です`);
    }
  } else {
    console.warn(`⚠️ ${label} が未定義または null です（値: ${value}）`);
  }
  
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

