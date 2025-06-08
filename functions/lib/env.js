// lib/env.js
// =======================================
// ✅ Firebase Functions 向け 環境変数定義ファイル
// ---------------------------------------
// 💡 本ファイルは Secrets や定数の安全かつ柔軟な管理を目的としています。
// 🔐 機密性の高い値（アクセストークンやAPIキーなど）は、Secretsとして Firebase に登録しておき、
//    ここでは projectId（GCLOUD_PROJECT）を元に、環境（本番 / 開発）を自動判定して出し分けます。
// -------------------------------
// ✅ ポイント：変数定義 → 条件分岐 → ログ出力 の順序を厳守！
// Firebaseでは Secrets が非同期で反映されることがあるため、
// 順番を間違えると「undefined」「未定義のままログ出力」になりやすい
// =======================================


// =======================================
// 🔹 ステップ 1：環境判定
// ---------------------------------------
// Firebase Functions 環境では、デプロイ時に GCLOUD_PROJECT が自動で注入されます。
// これを元に、本番環境か開発環境かを判断します。
// つまり GCLOUD_PROJECT は Firebase Functions v2 では自動的に設定されます
// 本番/開発の判定にはこの値を使用します（Secrets不要）
// ただしローカル(リッチメニュー作成など)での直接実行（node単体）では undefined になるので
// .env.secrets.ff*.txt を直接読み込むなど工夫が必要です
// =======================================

const projectId = process.env.GCLOUD_PROJECT || ""; // ← 明示的に fallback を指定して安全性確保
const isProd = projectId === "inuichiba-ffprod";    // ← 本番プロジェクトIDと一致すれば本番環境
const isDev = !isProd;                              // ← 本番でなければ開発環境とみなす
const isPreview = false;                            // ← Firebase には preview 概念なし


// =======================================
// 🔹 ステップ 2：全Secrets読み込み箇所に BOM & trim()など安全処理を施す
// ---------------------------------------
// スクリプト側で BOM を除去しても「完全には防げない」ため
// .ps1 などでSecrets登録前に改行やBOMを除去していても、
// gcloud CLIやローカルエディタのクセで BOM が入るケースは完全には防げません。
// そのため、「アプリ側で安全処理」を入れておくのは
// 実運用における二重セーフティとしてとても優れた設計です。
// ステップ 3 で使います。
// =======================================

function sanitizeEnvVar(value) {
  if (typeof value !== "string") return value;
  let v = value;
  if (v.charAt(0) === "\uFEFF") v = v.slice(1); // BOM削除
  return v.trim();
}


// =======================================
// 🔹 ステップ 3：GitHub Secretsから読み込む値（Firebase Config経由）
// ---------------------------------------
// ※ GitHub の Settings > Secrets and variables > Actions に登録された値は、
//    GitHub Actions 内で firebase functions:config:set により
//    Firebase Functions に注入されます。
//
//    config().xxx で参照可能ですが、Functions v2 では
//    デプロイ直後に反映遅延が起きることがあるため、
//    取得した値はログ出力前に .trim() や BOM 除去などのサニタイズを推奨します。
// =======================================

const { config } = require("firebase-functions/v2");

let cfg = {};
try {
  cfg = config(); // 👈 必ず定義する！
} catch (e) {
  console.warn("⚠️ config() 初期化前（Cloud Runなど）");
  cfg = {};
}

let accessToken =  
  isProd ? cfg?.line?.token?.ffprod || "" : cfg?.line?.token?.ffdev || "";
const channelAccessToken = sanitizeEnvVar(accessToken);

let secret =
  isProd ? cfg?.line?.secret?.ffprod || "" : cfg?.line?.secret?.ffdev || "";
const channelSecret = sanitizeEnvVar(secret);

// 本番/開発共通の Supabase サービスキー
let key = cfg?.supabase?.roll?.key || ""; 
const supabaseKey = sanitizeEnvVar(key);


// =======================================
// 🔹 ステップ 4：Secretsではなく定数でよい値（URL, テーブル名）
// ---------------------------------------
// Supabase の URL や テーブル名は Secrets にしなくても安全です。
// なぜなら URL は公開前提であり、テーブル名はセキュリティとは無関係な定義情報だからです。
// =======================================

const supabaseUrl = "https://ollbklkdnzonbxopfwqk.supabase.co";
const usersTable = isProd ? "users_ffprod" : "users_ffdev";


// =======================================
// 🔹 ステップ 5：LINE画像・カルーセルメッセージ用の共通URLやパス
// ---------------------------------------
// Cloudflare Pages にアップした画像を参照するURLです。
// 現在はどちらの環境でも共通で問題ない設計です。
// =======================================
// 実体は D:\nasubi\inuichiba-ffimages\public 配下にある
const baseDir = "https://inuichiba-ffimages.pages.dev/";

// コンテンツの相対パス(画像をファイルとして読み込むとき。今はリッチメニューだけ)
// 実体は D:\nasubi\inuichiba_ff\functions\richmenu-manager\data 配下にある 
const path = require("path");
const imageDir = path.resolve(__dirname, "../richmenu-manager/data/");

/** 
// =======================================
// 🔹 ステップ 5：Secrets名一覧（functions/index.js から参照される）
// ---------------------------------------
// deploy 時、ここで指定された Secrets 名だけが Firebase Functions にバインドされます。
// 無駄なバージョン増加を防ぐため、最低限に抑えています。
// =======================================

 const secretNames = isProd
  ? [
      "CHANNEL_ACCESS_TOKEN_PROD",
      "CHANNEL_SECRET_PROD",
      "SUPABASE_SERVICE_ROLE_KEY"
    ]
  : [
      "CHANNEL_ACCESS_TOKEN_DEV",
      "CHANNEL_SECRET_DEV",
      "SUPABASE_SERVICE_ROLE_KEY"
    ];
*/

// =======================================
// 🔹 ステップ 6：安全なログ出力（console.logで機密を出さない工夫）
// ---------------------------------------
// Secretsの値は出力しないよう、「長さ」「先頭文字列」などに制限して確認します。
// 呼び出したらisProd/!isProdにかかわらず表示しますので注意しましょうね
// =======================================

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

// テスト中のみ！終わったら削除！！
logSecretSafe("channelSecret", channelSecret);
logSecretSafe("channelAccessToken", channelAccessToken);


// ローカルテスト時やffdev環境時にだけログを出す
if (!isProd) {
  console.log("🐾 環境判定された projectId(GCLOUD_PROJECT):", projectId || "(未定義)");
  console.log("🐾 isProd:", isProd);
  logSecretSafe("channelSecret", channelSecret);
  logSecretSafe("channelAccessToken", channelAccessToken);
  console.log("📦 Supabase URL:", supabaseUrl);
  console.log("📦 Supabase Table(usersTable):", usersTable);
  console.log("📦 Supabase Key:", supabaseKey ? "✅ OK" : "❌ NG");
}


// =======================================
// 🔹 ステップ 7：外部にエクスポートする値一覧
// ---------------------------------------
// Firebase Functions 内で共通して参照される変数たちです。
// ここに追加すれば、他のJSファイルで require して使えます。
// =======================================

module.exports = {
  isProd,
  isDev,
  isPreview,
  channelAccessToken,
  channelSecret,
  supabaseKey,
  supabaseUrl,
  usersTable,
  baseDir,
  imageDir
};
