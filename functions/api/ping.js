// functions/api/ping.js

/**
 * Firebase Functions V2 に対する ping 用エンドポイント。
 * コールドスタート防止や動作確認用で使用。
 * 副作用なし。常設して問題なし。
 */
module.exports = (req, res) => {
  res.status(200).send("pong");
};
