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

// 初期化用のミドルウェア変数
let lineMiddleware = null;

// Webhook POSTエンドポイント
app.post("/api/webhook", function (req, res) {
  var env = require("./lib/env.js");
  var channelAccessToken = env.channelAccessToken;
  var channelSecret = env.channelSecret;
  var isProd = env.isProd;

  if (!channelAccessToken || !channelSecret) {
    console.error("🔐 channelAccessToken または channelSecret が未定義です");
    res.status(500).send("LINE設定が未定義です");
    return;
  }

  if (!lineMiddleware) {
    lineMiddleware = line.middleware({
      channelAccessToken: channelAccessToken,
      channelSecret: channelSecret
    });
    if (!isProd) {
      console.log("✅ LINEミドルウェア初期化完了");
    }
  }


  try {
    lineMiddleware(req, res, function () {
      var events = req.body && req.body.events;
      if (!events || !(events instanceof Array) || events.length === 0) {
        if (!isProd) {
          console.warn("⚠️ 無効なイベントです:", req.body);
        }
        res.status(200).send("No events");
        return;
      }

      var i = 0;

      function processNextEvent(index) {
        if (index >= events.length) {
          res.status(200).send("OK from webhook");
          return;
        }

        try {
          eventsHandler.handleEvent(events[index], channelAccessToken)
            .then(function () {
              processNextEvent(index + 1);
            })
            .catch(function (err) {
              console.error("💥 handleEvent エラー:", err);
              res.status(500).send("Internal Server Error");
            });
        } catch (e) {
          console.error("💥 イベント処理中の例外:", e);
          res.status(500).send("Internal Server Error");
        }
      }

      processNextEvent(i);
    });
  } catch (e) {
    console.error("💥 Webhook全体のエラー:", e);
    res.status(500).send("Internal Server Error");
  }
});

// Webhook GET確認用
app.get("/api/webhook", function (req, res) {
  res.status(200).send("OK (GET from webhook)");
});

// Functionsエクスポート
exports.webhook = functions.https.onRequest({ region: region }, app);
exports.ping = functions.https.onRequest({ region: region }, require("./api/ping"));

