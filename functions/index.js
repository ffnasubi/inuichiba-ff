// ✅ 最小構成の functions/index.js（Hello World）

// functions/index.js
const functions = require("firebase-functions/v2");
const { onRequest } = functions.https;
const region = "asia-northeast1";

// 🔐 Firebase Functions にバインドする Secrets 一覧（ここが超重要！！）
const secrets = [
  "NODE_ENV",
  "CHANNEL_ACCESS_TOKEN_PROD",
  "CHANNEL_SECRET_PROD",
  "SUPABASE_SERVICE_ROLE_KEY_PROD",
  "SUPABASE_TABLE_NAME_PROD",
  "SUPABASE_URL",
  "MY_LINE_USER_ID"
];

// 🔍 環境変数チェック用に env.js を読み込む
const env = require("./lib/env.js");

exports.hello = onRequest({ region, secrets }, (req, res) => {
  console.log("🔥 Hello Function Invoked!");
  res.send("Hello from Firebase!");
});

