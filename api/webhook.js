// api/webhook.js（Firebase Functions 用・遅延読み込み対応）

const { middleware } = require('@line/bot-sdk');
const { handleEvent } = require('../functions/handlers/events.js');

const config = {
  api: {
    bodyParser: false,
  },
};

async function handler(req, res) {
  // ✅ 遅延 require：Secrets を確実に初期化後に読み込む
  const { channelAccessToken, channelSecret, envName, isProd } = require('../functions/lib/env.js');
  if (!isProd) {
    console.log("✅ Webhook関数に到達！");
    console.log("🔍 環境:", envName);
    console.log("🔍 リクエスト URL:", req.url);
    console.log("🔍 メソッド:", req.method);
    console.log("🔍 x-line-signature:", req.headers['x-line-signature']);
  }

  if (req.method !== 'POST') {
    if (!isProd) console.log("🚫 Not a POST request, skipping...");
    return res.status(200).send('OK (not POST)');
  }

  try {
    const lineMiddleware = middleware({ channelAccessToken, channelSecret });

    await new Promise((resolve, reject) => {
      lineMiddleware(req, res, (err) => {
        if (err) {
          console.error("❌ Middleware error:", err.message);
          res.status(401).send("Unauthorized");
          return reject(err);
        }
        resolve();
      });
    });

    const events = req.body?.events;
    if (!events || !Array.isArray(events)) {
      if (!isProd) console.warn("⚠️ イベント配列が不正です:", req.body);
      return res.status(200).send("No events");
    }

    for (const event of events) {
      await handleEvent(event, channelAccessToken);
    }

    res.status(200).send("OK from webhook");
  } catch (err) {
    console.error("💥 Error in webhook handler:", err);
    res.status(500).send("Internal Server Error");
  }
}

module.exports = {
  config,
  handler
};

