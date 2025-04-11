// api/webhook.js
const { middleware } = require('@line/bot-sdk');
const { channelAccessToken, channelSecret, envName, vercelBypassSecret } = require('../lib/env.js');
const { handleEvent } = require('../functions/handlers/events.js');
 
const lineMiddleware = middleware({
  channelAccessToken,
  channelSecret,
});

export const config = {
  api: {
    bodyParser: false,
  },
};
 
export default async function handler(req, res) {
  console.log("✅ Webhook関数に到達！");
  console.log("🔍 環境:", envName);
  console.log("🔍 リクエスト URL:", req.url);
  console.log("🔍 メソッド:", req.method);
  console.log("🔍 x-line-signature:", req.headers['x-line-signature']);
  console.log("🔑 channelSecret used in middleware:", channelSecret);
	
	// POSTのみ対象
	if (process.env.VERCEL_ENV === 'preview' &&
			req.headers['x-vercel-protection-bypass'] !== vercelBypassSecret ) {
				console.warn("🚫 Protection Bypass ヘッダー不一致！");
				return res.status(401).send("Unauthorized (Vercel Protection)");
	}

  if (req.method !== 'POST') {
    console.log("🚫 Not a POST request, skipping...");
    return res.status(200).send('OK (not POST)');
  }

  try {
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
      console.warn("⚠️ イベント配列が不正です:", req.body);
      return res.status(200).send("No events");
    }

for (const [i, event] of events.entries()) {
  // 最初の一度のeventだけコンソールログを出す
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
}
