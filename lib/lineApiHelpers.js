import axios from 'axios';

// ///////////////////////////////////////////////
// Replyメッセージ送信
export async function sendReplyMessage(replyToken, messages, ACCESS_TOKEN) {
  const url = 'https://api.line.me/v2/bot/message/reply';

  try {
    const response = await axios.post(
      url,
      { replyToken, messages },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${ACCESS_TOKEN}`,
        }
      }
    );
    console.log("LINEメッセージ送信成功", response.data);
  } catch (error) {
    if (error.response) {
      console.error("❌ LINEメッセージ送信失敗:", error.response.status);
    } else {
      console.error("❌ ネットワークまたはaxiosレベルのエラー:", error.message);
    }
  }
}

// ///////////////////////////////////////////////
// プッシュメッセージ送信
export async function sendPushMessage(userId, messages, ACCESS_TOKEN) {
  const url = 'https://api.line.me/v2/bot/message/push';

  try {
    const response = await axios.post(
      url,
      {
        to: userId,
        messages: messages
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${ACCESS_TOKEN}`
        }
      }
    );
    console.log('プッシュ成功:', response.data);
  } catch (error) {
    console.error('プッシュエラー:', error.response ? error.response.data : error.message);
  }
}

// //////////////////////////////////////////////////
// LINEのユーザプロフィールをまとめて取得する
export async function getUserProfile(userId, ACCESS_TOKEN) {
  const url = `https://api.line.me/v2/bot/profile/${userId}`;

  try {
    const response = await axios.get(url, {
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`
      }
    });

    return response.data;
  } catch (error) {
    console.error("❌ ユーザープロフィール取得失敗:", error.message);
    return null;
  }
}
