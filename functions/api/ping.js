// functions/api/ping.js

/**
 * Firebase Functions V2 (Cloudflare Pages 経由) に対する ping 用エンドポイント。
 * コールドスタート防止や動作確認用で使用。
 * 副作用なし。常設して問題なし。
 */
exports.ping = (req, res) => {
  res.status(200).send("pong");
};
