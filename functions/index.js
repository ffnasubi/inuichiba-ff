// functions/index.js（Firebase Functions 移植版）

const functions = require("firebase-functions/v2"); // ✅ v2 API を明示的に使用！
const express = require("express");
const { middleware } = require("@line/bot-sdk");
const { channelAccessToken, channelSecret, isProd, envName } = require("./lib/env.js");
const { handleEvent } = require("./handlers/events.js");
const region = "asia-northeast1"; // ✅ 東京リージョン（Gen2には必要）

// Expressアプリを作成
const app = express();

// LINEミドルウェア（署名検証）
const lineMiddleware = middleware({ channelAccessToken, channelSecret });

// リクエストbodyを生で扱うための設定（LINE署名検証に必要）
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

// Webhookエンドポイント（/api/webhook で待ち受け）
app.post("/api/webhook", lineMiddleware, async (req, res) => {
  if (!isProd) {
    console.log("✅ Webhook関数に到達！");
    console.log("🔍 環境:", envName);
    console.log("🔍 リクエスト URL:", req.originalUrl);
    console.log("🔍 メソッド:", req.method);
    console.log("🔍 x-line-signature:", req.headers['x-line-signature']);
    console.log("🔑 channelSecret used in middleware:", channelSecret);
  }

  try {
    const events = req.body?.events;
    if (!events || !Array.isArray(events)) {
      console.warn("⚠️ イベント配列が不正です:", req.body);
      return res.status(200).send("No events");
    }

    for (const [i, event] of events.entries()) {
      if (i === 0) {
        console.log("🔐 channelAccessToken の長さ:", channelAccessToken?.length);
      }
      await handleEvent(event, channelAccessToken);
    }

    res.status(200).send("OK from webhook");
  } catch (err) {
    console.error("💥 Error in webhook handler:", err);
    res.status(500).send("Internal Server Error");
  }
});

// ✅ Firebase Functions v2 としてエクスポート（Gen 2 明示）
exports.webhook = functions
  .https.onRequest({
    region,
    secrets: ["NODE_ENV"],
  }, app);

exports.api = functions
  .https.onRequest({
    region,
    secrets: ["NODE_ENV"],
  }, app);
