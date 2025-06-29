const express = require("express");
const { onRequest } = require("firebase-functions/v2/https");
const getEnv = require("./lib/env.js");
const { handleEvent } = require("./handlers/events.js");

// 環境情報の取得
const { isProd, getMiddleware } = getEnv();

const app = express();

// 🔧 生のリクエストボディを取得（LINE署名検証用）
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

// ✅ LINE ミドルウェア（署名検証を含む）
const LineMiddleware = getMiddleware();
app.use(LineMiddleware);

// 📮 POST: Webhook イベント受信（LINE専用）
app.post("/", async (req, res) => {
  const events = req.body?.events;
  if (!Array.isArray(events)) {
    if (!isProd) console.warn("⚠️ 無効なイベント形式:", req.body);
    return res.status(400).send("Invalid request");
  }

  try {
    let idx = 0;
    async function processNextEvent(idx) {
      if (idx >= events.length) {
        return res.status(200).send("OK from webhook");
      }
        
      try {
        const { channelAccessToken } = require("./lib/env.js")();
        await handleEvent(events[idx], channelAccessToken);
        await processNextEvent(idx + 1);
      } catch (err) {
        console.error("💥 handleEvent エラー:", err);
        res.status(500).send("Internal Server Error");
      }
    }

    await processNextEvent(idx);

  } catch (err) {
    console.error("❌ イベント処理中のエラー:", err);
    res.status(500).send("Internal Server Error");
  }
});

// 🧪 GET: 動作確認用
app.get("/", (req, res) => {
  res.status(200).send("👋 Hello from LINE Webhook!");
});

const pingApp = require("./api/ping");

// 🧪 GET: ping動作確認用
pingApp.get("/", (req, res) => {
  res.status(200).send("👋 pong");
});

// 🧩 Firebase Functions に登録
exports.webhook = onRequest({ region: "asia-northeast1" }, app);

exports.ping = onRequest({ region }, pingApp);
