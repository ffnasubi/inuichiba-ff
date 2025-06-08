// functions/index.js（Firebase Functions 移植版）
// 順番注意。初期化エラー防止のため。require → 設定チェック → ミドルウェア初期化 の流れに統一
// 非同期処理の繰り返しは processNextEvent(index) による再帰で管理
// Secrets などの安全な読み込み順序確保。functions.https.onRequest() より後に初期化する

// ✅ 最初に必要なモジュールを読み込む
const functions = require("firebase-functions/v2");
const express = require("express");
// const { webhook } = require("./api/webhook"); 
const { middleware } = require("@line/bot-sdk");
const { handleEvent } = require("./handlers/events.js");
const region = "asia-northeast1";
 
// ✅ Expressアプリを作成
const app = express();

// ✅ リクエストbodyを生で扱うための設定（LINE署名検証に必要）
app.use(express.json({
  verify: function(req, res, buf) {
    req.rawBody = buf;
  }
}));

// ✅ Secretsからの読み込みは関数の中で行う（未定義エラー防止のため）
let lineMiddleware;

try {
  const { channelAccessToken, channelSecret, isProd } = require("./lib/env.js");

  if (!channelAccessToken || !channelSecret) {
    if (!isProd) console.warn("🔐 LINE設定が未定義です（Secretsの設定不足または読み込みタイミングの問題）");
  }

  lineMiddleware = middleware({ channelAccessToken: channelAccessToken, channelSecret: channelSecret });
  if (!isProd) console.log("✅ LINEミドルウェア初期化完了");
} catch (err) {
  const { isProd } = require("./lib/env.js");
  if (!isProd) console.error("💥 LINE設定の初期化エラー:", err);
}

// ✅ Webhookエンドポイント（/api/webhook で待ち受け）
app.post("/api/webhook", function(req, res) {
  const { isProd } = require("./lib/env.js");
  if (!isProd) console.log("✅ POST /api/webhook に到達しました！");
  try {
    if (!lineMiddleware) {
      throw new Error("🔐 LINEミドルウェアが初期化されていません。");
    }

    lineMiddleware(req, res, async function() {
      const { isProd } = require("./lib/env.js");
      
      const events = req.body && req.body.events;
      if (!events || !(events instanceof Array)) {
        if (!isProd) console.warn("⚠️ イベント配列が不正です:", req.body);
        return res.status(200).send("No events");
      }

      let i = 0;
      async function processNextEvent(index) {
        if (index >= events.length) {
          return res.status(200).send("OK from webhook");
        }
        
        try {
          const { channelAccessToken } = require("./lib/env.js");
          await handleEvent(events[index], channelAccessToken);
          await processNextEvent(index + 1);
        } catch (err) {
          console.error("💥 handleEvent エラー:", err);
          res.status(500).send("Internal Server Error");
        }
      }

      await processNextEvent(i);
    });
  } catch (err) {
    console.error("💥 Webhookハンドラーエラー:", err);
    res.status(500).send("Internal Server Error");
  }
});

// FF構成で webhook GET を処理する
app.get("/api/webhook", function(req, res) {
  res.status(200).send("OK (GET from webhook)");
});


// ✅ Firebase Functions v2 としてエクスポート
exports.webhook = functions
  .https
  .onRequest({ region: region }, app);

// ✅ functions/api/ping.js を読み込んで関数として登録
// 一日に一度pingを叩いてffmainを起こす
exports.ping = functions
  .https
  .onRequest({ region: region }, require("./api/ping"));


// exports.helloWorld = require("./helloWorld").helloWorld;


