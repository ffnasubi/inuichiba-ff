// lib/env.js
// Firebase Functions 向けの環境変数設定ファイル
// 変数定義 → 条件分岐 → ログ出力の順に記述することで、未初期化エラーを防ぎます(厳守)！

// Node.jsに.env.*を開発環境に応じて読み込ませる
import { config as loadEnv } from 'dotenv';

// 1. 環境ファイルの読み込み（ローカル用）
// Firebase Functions では自動的に環境変数が読み込まれるため、
// この読み込みはローカル開発時のみ必要
const envPath = process.env.NODE_ENV === "production"
  ? ".env.ffprod"
  : ".env.ffdev";
loadEnv({ path: envPath });


// 2. 環境モードの判定
// Firebase では Vercel のような preview モードは存在しません
// NODE_ENV によって production / development を判定します
const rawEnv = process.env.NODE_ENV ?? 'development';


// 3. 環境フラグ
export const isProd = rawEnv === "production";
export const isDev = rawEnv === "development";
export const isPreview = false; // Firebase Functionsではpreview概念は存在しない


// 4. 環境に依存する設定値（もうここではisProdを使ってOK）
// 本番環境と開発環境とに応じて切り分ける
export const channelAccessToken = isProd
  ? process.env.CHANNEL_ACCESS_TOKEN_PROD
  : process.env.CHANNEL_ACCESS_TOKEN_DEV;

export const channelSecret = isProd
  ? process.env.CHANNEL_SECRET_PROD
  : process.env.CHANNEL_SECRET_DEV;

// 使用する Supabase テーブル名を、環境によって切り替える
export const usersTable = isProd
  ? process.env.SUPABASE_TABLE_NAME_PROD
  : process.env.SUPABASE_TABLE_NAME_DEV;

export const supabaseKey = isProd
  ? process.env.SUPABASE_SERVICE_ROLE_KEY_PROD
  : process.env.SUPABASE_SERVICE_ROLE_KEY_DEV;

export const supabaseUrl = process.env.SUPABASE_URL;

// Firebase Functions では vercelBypassSecret は基本未使用（必要に応じて）
export const vercelBypassSecret = process.env.VERCEL_PROTECTION_BYPASS_SECRET;

// LINE Bot管理者用のユーザーID。Supabaseに書き込む時のuserId。確認にひとつは必須
export const myLineUserId = process.env.MY_LINE_USER_ID;

// コンテンツのホスティングURL（画像とカルーセルメッセージのベースパス）
export const baseDir = isProd
  ? "https://inuichiba-ffprod.web.app/"
  : "https://inuichiba-ffdev.web.app/";

// メニュー名：メニューキャッシュクリアや更新確認に使用
// ローカルテスト用で現在未使用。.env.*のみ一応定義。
export const targetMenuName = process.env.TARGET_MENU_NAME;

// 5. 環境名の最後の定義(ログ出力)
// ✅ 最後に定義！ ← これが正解
// (まだ envName が未初期化の状態で使われてしまうとクラッシュする)
export const envName = rawEnv;

// ✅ ログ出力（使うのは最後の最後！）
// console.log() は定義後に！それ以前に使うと未初期化になる
if (!isProd) {
  console.log("🐾 環境判定された envName:", envName);
	console.log("🔐 channelSecret:", channelSecret);
	console.log("📦 Supabase URL:", supabaseUrl);
  console.log("📦 Supabase Table(usersTable):", usersTable);
  console.log("📦 supabaseKey:", supabaseKey ? "✅ OK" : "❌ NG");
}



