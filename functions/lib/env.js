// lib/env.js
// ================================
// Firebase Functions 向けの環境変数設定ファイル
// -------------------------------
// ✅ ポイント：変数定義 → 条件分岐 → ログ出力 の順序を厳守！
// Firebaseでは Secrets が非同期で反映されることがあるため、
// 順番を間違えると「undefined」「未定義のままログ出力」になりやすい
// ================================


// 1. NODE_ENV のデフォルト設定（明示的に）
process.env.NODE_ENV = process.env.NODE_ENV || "production";


// 2. プロジェクトIDによる本番／開発判定
// Firebase Functions では GCLOUD_PROJECT が自動的にセットされる
// ローカル開発環境では未定義なので、この判定はSecretsでセットされた値が前提
const projectId = process.env.GCLOUD_PROJECT || "";
const isProd = projectId === "inuichiba-ffprod";
const isDev = !isProd;
const isPreview = false; // Firebase では preview 環境の概念はなし

// NODE_ENVベースの環境名判定
const rawEnv = (process.env.NODE_ENV || 'production').trim().toLowerCase();


// 3. 環境変数の取得（isProd に応じて）
// それぞれに trim(), BOM削除など安全処理を施している
let channelAccessToken = isProd
  ? process.env.CHANNEL_ACCESS_TOKEN_PROD
  : process.env.CHANNEL_ACCESS_TOKEN_DEV;
// もし両端にスペースや改行が入ってた時の対処
let envToken = channelAccessToken;
if (typeof envToken === "string") {
  if (envToken.charAt(0) === "\uFEFF" && envToken.length > 0) {
    envToken = envToken.slice(1);   // BOM削除
  }
  channelAccessToken = envToken.trim();
}

// チャネルシークレット(LINEの秘匿コード)
let channelSecret = isProd
  ? process.env.CHANNEL_SECRET_PROD
  : process.env.CHANNEL_SECRET_DEV;
// もし両端にスペースや改行が入ってた時の対処
let envSecret = channelSecret;
if (typeof envSecret === "string" && envSecret.length > 0) {
  if (envSecret.charAt(0) === "\uFEFF") {
    envSecret = envSecret.slice(1); // BOM削除
  }
  channelSecret = envSecret.trim();
}

// 使用する Supabase テーブル名
let usersTable = isProd
  ? process.env.SUPABASE_TABLE_NAME_PROD
  : process.env.SUPABASE_TABLE_NAME_DEV;
// もし両端にスペースや改行が入ってた時の対処
let envTable = usersTable;
if (typeof envTable === "string" && envTable.length > 0) {
  if (envTable.charAt(0) === "\uFEFF") {
    envTable = envTable.slice(1); // BOM削除
  }
  usersTable = envTable.trim();
}

let supabaseKey = isProd
  ? process.env.SUPABASE_SERVICE_ROLE_KEY_PROD
  : process.env.SUPABASE_SERVICE_ROLE_KEY_DEV;
// もし両端にスペースや改行が入ってた時の対処
let envKey = supabaseKey;
if (typeof envKey === "string" && envKey.length > 0) {
  if (envKey.charAt(0) === "\uFEFF") {
    envKey = envKey.slice(1); // BOM削除
  }
  supabaseKey = envKey.trim();
}

let supabaseUrl = process.env.SUPABASE_URL;
// もし両端にスペースや改行が入ってた時の対処
let envUrl = supabaseUrl;
if (typeof envUrl === "string" && envUrl.length > 0) {
  if (envUrl.charAt(0) === "\uFEFF") {
    envUrl = envUrl.slice(1); // BOM削除
  }
  supabaseUrl = envUrl.trim();
}

// LINE Bot管理者用のユーザーID。Supabaseに書き込む時のuserId。確認にひとつは必須
let myLineUserId = process.env.MY_LINE_USER_ID;
// もし両端にスペースや改行が入ってた時の対処
let envId = myLineUserId;
if (typeof envId === "string" && envId.length > 0) {
  if (envId.charAt(0) === "\uFEFF") {
    envId = envId.slice(1); // BOM削除
  }
  myLineUserId = envId.trim();
}

// コンテンツのホスティングURL（画像とカルーセルメッセージのベースパス）
const baseDir = isProd
  ? "https://inuichiba-ffprod.web.app/"
  : "https://inuichiba-ffdev.web.app/";

// 未使用：メニュー名：メニューキャッシュクリアや更新確認に使用(ローカルテスト用)
// .env.*だけに定義を残して他はコメントアウトしてる
// なお使用するときは末尾のexports定義も忘れずに行うこと
// let targetMenuName = process.env.TARGET_MENU_NAME;
// let envName = targetMenuName;
// if (typeof envName === "string" && envName.length > 0) {
//  if (envName.charAt(0) === "\uFEFF") {
//    envName = envName.slice(1); // BOM削除
//  }
//  targetMenuName = envName.trim();
// }


// 4. 環境名の最後の定義(ログ出力)
// ✅ 最後に定義！ ← これが正解
// (まだ envName が未初期化の状態で使われてしまうとクラッシュする)
const envName = rawEnv;


// ✅ ログ出力（使うのは最後の最後！）
// console.*() は定義後に！それ以前に使うと未初期化になる

// FF環境ではこの時点で初期化は間に合ってないのでログ出しても読み込みエラーになる
// なのでコンソールログを抑制する
// ログは PowerShell で以下のコマンドで確認すること
// gcloud functions logs read webhook --region=asia-northeast1 --project=inuichiba-ffprod
/**
if (isProd) {
  console.log("🧪 NODE_ENVは本番環境反映済?(process.env.FUNCTION_TARGET):", process.env.FUNCTION_TARGET || "(not set)");
  console.log("✅ NODE_ENV(process.env.NODE_ENV):", process.env.NODE_ENV);
	logSecretSafe("channelSecret(process.env.CHANNEL_SECRET_PROD):", process.env.CHANNEL_SECRET_PROD);
  logSecretSafe("channelAccessToken(process.env.CHANNEL_ACCESS_TOKEN_PROD)", process.env.CHANNEL_ACCESS_TOKEN_PROD);
  console.log("📦 Supabase URL(process.env.SUPABASE_URL):", process.env.SUPABASE_URL);
  console.log("📦 Supabase Table PROD（process.env.SUPABASE_TABLE_NAME_PROD）:", process.env.SUPABASE_TABLE_NAME_PROD || "❌ undefined");
  console.log("📦 Supabase Key PROD（process.env.SUPABASE_SERVICE_ROLE_KEY_PROD読込）:", process.env.SUPABASE_SERVICE_ROLE_KEY_PROD ? "✅ OK" : "❌ NG");
}
*/

// ✅ すべての環境変数の読み込みと加工が終わった直後
// つまり、module.exports の前 or 直前！
if (!isProd) {
  console.log("🐾 環境判定された envName:", envName);
  console.log("🐾 プロジェクトID(GCLOUD_PROJECT):", projectId || "(未定義)");
  console.log("🐾 isProd:", isProd);
	logSecretSafe("channelSecret:", channelSecret);
  logSecretSafe("channelAccessToken", channelAccessToken);
  console.log("📦 Supabase URL:", supabaseUrl);
  console.log("📦 Supabase Table(usersTable):", usersTable);
  console.log("📦 supabaseKey:", supabaseKey ? "✅ OK" : "❌ NG");
}


// 🔒 ログに機密情報を出さないための安全な関数
function logSecretSafe(label, value) {
  if (typeof value === "string") {
    if (value.length > 0) {
      if (!isProd) {
        console.log(`🔐 ${label} の長さ: ${value.length}`);
        console.log(`🔐 ${label} の先頭5文字: ${value.slice(0, 5)}...`);
        console.log(`🔐 ${label} の末尾5文字: ${value.slice(-5)}`);
            }
    } else {
      if (!isProd) console.warn(`⚠️ ${label} は空文字列です`);
    }
  } else {
    if (!isProd) console.warn(`⚠️ ${label} が未定義または null です（値: ${value}）`);
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
  baseDir
};

