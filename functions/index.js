// functions/index.js（Firebase Functions 移植版）

const functions = require("firebase-functions");
const express = require("express");
const { middleware } = require("@line/bot-sdk");
const { channelAccessToken, channelSecret, envName, vercelBypassSecret } = require("./lib/env.js");
const { handleEvent } = require("./handlers/events.js");

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

// Webhookエンドポイント
app.post("/api/webhook", lineMiddleware, async (req, res) => {
  console.log("✅ Webhook関数に到達！");
  console.log("🔍 環境:", envName);
  console.log("🔍 リクエスト URL:", req.originalUrl);
  console.log("🔍 メソッド:", req.method);
  console.log("🔍 x-line-signature:", req.headers['x-line-signature']);
  console.log("🔑 channelSecret used in middleware:", channelSecret);

  // Firebase環境ではVercel保護は不要だが、念のため残す
  if (envName === 'preview' &&
      req.headers['x-vercel-protection-bypass'] !== vercelBypassSecret) {
    console.warn("🚫 Protection Bypass ヘッダー不一致！");
    return res.status(401).send("Unauthorized (Vercel Protection)");
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

// Firebase Function としてエクスポート
exports.api = functions.https.onRequest(app);
