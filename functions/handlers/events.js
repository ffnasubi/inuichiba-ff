// functions/handlers/events.js
// ✅ 最新版：events.js（.then → await / catch に統一、ログ抑制付き）

const { saveUserProfileAndWrite } = require(../lib/saveUserInfo.js);
const { sendReplyMessage, getUserProfile } = require(../lib/lineApiHelpers.js);
const { textMessages, mediaMessages, lineQRMessages, textTemplates, emojiMap } = require(../richmenu-manager/data/messages.js);
const messages = require(../richmenu-manager/data/messages.js);


// ///////////////////////////////////////////
// eventタイプで処理を振り分ける
export async function handleEvent(event, ACCESS_TOKEN) {
  switch (event.type) {
    case 'message':
      await handleMessageEvent(event, ACCESS_TOKEN);
      break;

    case 'postback':
      await handlePostbackEvent(event, ACCESS_TOKEN);
      break;

    case 'follow':
      await handleFollowEvent(event, ACCESS_TOKEN);
      break;

    case 'unfollow':
      console.log("🔕 ブロックされました:", event.source?.userId);
      break;

    case 'join':
      await handleJoinEvent(event, ACCESS_TOKEN);
      break;

    case 'leave':
      console.log("🚪 グループから削除されました:", event.source?.groupId || event.source?.roomId);
      break;

    case 'memberJoined':
      console.log("👧 誰かがグループに参加しました:", event.source?.groupId || event.source?.roomId);
      break;

    case 'memberLeft':
      console.log("👋 誰かがグループを退出しました:", event.source?.groupId || event.source?.roomId);
      break;

    default:
      console.log("❓ 未処理イベントタイプ:", event.type);
  }
}


// ///////////////////////////////////////////
// followイベントの処理（書き込みはあとから実行）
async function handleFollowEvent(event, ACCESS_TOKEN) {
  const userId = event.source?.userId;
  const groupId = event.source?.groupId || null;

  console.log("🟡 follow イベント開始:", { userId, groupId });

  // --- メッセージ生成＆返信
  const profile = await getUserProfile(userId, ACCESS_TOKEN);
  const displayName = profile?.displayName || null;
  const followText = textTemplates["msgFollow"];

  let mBody = (displayName == null || displayName.includes("$"))
    ? followText
    : `${displayName}さん、${followText}`;

  let message;
  try {
    const emojiTextMessage = buildEmojiMessage("msgFollow", mBody);
    message = emojiTextMessage;
  } catch (error) {
    console.warn(`⚠️ follow絵文字メッセージの構築失敗: ${error.message}`);
    message = { type: "text", text: "エラーが発生しました。" };
  }

  await sendReplyMessage(event.replyToken, [message], ACCESS_TOKEN);

  // --- 書き込みはあとで非同期に（UI優先！）
  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
      console.log("✅ Supabase 書き込み完了 (follow)");
    } catch (err) {
      console.warn("⚠️ follow 書き込み失敗:", err.message);
    }
  }

}


// ///////////////////////////////////////////
// messageイベントの処理（書き込みは後ろで非同期）
async function handleMessageEvent(event, ACCESS_TOKEN) {
	const userId = event.source?.userId ?? null;
	const sourceType = event.source?.type ?? null;  // 'user' | 'group' | 'room'
	const groupId = event.source?.type === "group" ? event.source.groupId : null;
  const data = event.message.text;
	
	let message = [];
	
	// LINE公式アカウントの「自動応答対象ワード」はBotが代わりに返信
	if (data === "QRコード" || data === "友だち追加") {
    message = lineQRMessages;
  } 
	// グループ or ルームからのメッセージは、LINE自動応答メッセージのみBotの代わりに返信
	// 他は完全に無視
	else if (sourceType === "group" || sourceType === "room") {
    return;
  }
  // 以下は「個人チャット」で、自動応答以外のメッセージ
	else if (data === "ワイワイ") {
    message = [{ type: "text", text: messages.msgY }];
  } 
	else {
    message = [{ type: "text", text: messages.msgPostpone }];
  }
	
  await sendReplyMessage(event.replyToken, message, ACCESS_TOKEN);

  // --- Supabase書き込みはメッセージ送信後、後回しに実行（非同期）
  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      console.log("⚠️ message書き込み失敗:", err.message);
    }
  }
	
}


// ///////////////////////////////////////////
// postbackイベント：リッチメニューのタップ処理へ委譲 + 書き込みは後回しで
async function handlePostbackEvent(event, ACCESS_TOKEN) {
  const userId = event.source?.userId;
  const groupId = event.source?.groupId;
  const data = event.postback.data;

  // --- A. メニュータップ系（返信処理）
  if (data.startsWith("tap_richMenu")) {
    await handleRichMenuTap(data, event.replyToken, ACCESS_TOKEN);
  }

  // --- B. タブ切り替えなど、今は何もしないケース
  if (data === "change to A" || data === "change to B") {
    return;
  }

  // --- C. 書き込みは後回しで実行（レスポンスに影響させない）
  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      console.log("⚠️ postback書き込み失敗:", err.message);
    }
  }
	
}


// ///////////////////////////////////////////
// リッチメニュータップのバッチ処理
async function handleRichMenuTap(data, replyToken, ACCESS_TOKEN) {
  let messages = [];

  console.log("🔍 postback data:", data, "（型:", typeof data, "）");

  if (mediaMessages[data]) {
    messages = mediaMessages[data];
  } else if (textMessages[data]) {
    messages = textMessages[data];
  } else if (data == "tap_richMenuA5") {
    await setCarouselMessage(replyToken, ACCESS_TOKEN);
    return;
  }

  try {
    if (textTemplates[data]) {
      const emojiTextMessage = buildEmojiMessage(data, "");
      messages.push(emojiTextMessage);
    }
  } catch (error) {
    console.warn(`⚠️ Postback絵文字メッセージの構築失敗: ${error.message}`);
  }

  if (messages.length === 0) {
    console.warn(`⚠️ Postbackで情報が見つかりませんでした: ${data.toString()}`);
  }

  if (messages.length > 0) {
    console.log("Reply Token:", replyToken);
    console.log("送信メッセージ:", JSON.stringify(messages, null, 2));
    await sendReplyMessage(replyToken, messages, ACCESS_TOKEN);
  }
}


// ///////////////////////////////////////////// 
// テキストメッセージの後にカルーセルメッセージを出力する
async function setCarouselMessage(replyToken, ACCESS_TOKEN) {
  const textMessage = {
    type: "text",
    text: messages.msgA5
  };

  const flex_message1 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: "https://inuichiba.vercel.app/carousel/cPark1.png",
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: "https://inuichiba.vercel.app/carousel/cPark1detail.png"
          }
        },
        {
          type: "text",
          text: "駐車場全体地図",
          align: "center",
          weight: "bold",
          size: "sm",
          color: "#333333"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#F3C2D5"
      }
    }
  };

  const flex_message2 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: "https://inuichiba.vercel.app/carousel/cPark2.png",
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: "https://inuichiba.vercel.app/carousel/cPark2detail.png"
          }
        },
        {
          type: "text",
          text: "駐車場全体地図",
          align: "center",
          weight: "bold",
          size: "sm",
          color: "#333333"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#F3C2D5"
      }
    }
  };

  const flex_message3 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: "https://inuichiba.vercel.app/carousel/cPark3.png",
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: "https://inuichiba.vercel.app/carousel/cPark3detail.png"
          }
        },
        {
          type: "text",
          text: "駐車場全体地図",
          align: "center",
          weight: "bold",
          size: "sm",
          color: "#333333"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#F3C2D5"
      }
    }
  };

  const carouselContents = [flex_message1, flex_message2, flex_message3];

  const flexMessage = {
    type: "flex",
    altText: "こちらはカルーセルメッセージです", 
    contents: {
      type: "carousel",
      contents: carouselContents
    }
  };
	
  console.log("📦 Flex Message 中身:", JSON.stringify(flexMessage, null, 2));
  console.log("🚀 実際に送るメッセージ:", [textMessage, flexMessage]);

  await sendReplyMessage(replyToken, [textMessage, flexMessage], ACCESS_TOKEN);
}


// /////////////////////////////////////////
// 絵文字入りメッセージを組み立てる
function buildEmojiMessage(templateKey, mBody) {
  let rawText = textTemplates[templateKey];
  const emojiList = emojiMap[templateKey];

  if (templateKey === "msgFollow") {
    rawText = mBody;
  }

  if (!rawText) {
    throw new Error(`テキストテンプレートが見つかりません: ${templateKey}`);
  }

  const placeholderCount = (rawText.match(/\$/g) || []).length;
  console.log("💡 placeholderCount ($の数):", placeholderCount);
  console.log("🔢 emojiList.length:", emojiList ? emojiList.length : 0);

  if (!emojiList || placeholderCount !== emojiList.length) {
    throw new Error(`$の数(${placeholderCount})とemojiListの数(${emojiList ? emojiList.length : 0})が一致しません: ${templateKey}`);
  }

  const emojis = [];
  let i = 0;
  let placeholderIndex = rawText.indexOf('$');  

  while (placeholderIndex !== -1) {
    emojis.push({
      index:     placeholderIndex,
      productId: emojiList[i].productId,
      emojiId:   emojiList[i].emojiId
    });

    placeholderIndex = rawText.indexOf("$", placeholderIndex + 1);
    i++;
  }

  console.log("📦 最終構築される emojis 配列:", emojis);
  console.log("✅ 最終返却メッセージ:", {
    type: "text",
    text: rawText,
    emojis: emojis
  });

  return {
    type: "text",
    text: rawText,
    emojis: emojis
  };
}


// ///////////////////////////////////////////
// joinイベント（グループやルームに招待されたときの挨拶）
async function handleJoinEvent(event, ACCESS_TOKEN) {
  const groupId = event.source?.groupId || event.source?.roomId || "不明";
  console.log("👋 joinイベント発生！グループまたはルームID:", groupId);

  const welcomeMessage = {
    type: "text",
    text: "こんにちは！犬市場Botです🐶\nどうぞよろしくお願いします！\nグループ通知が多い場合は、通知設定をオフにしてくださいね😊"
  };

  await sendReplyMessage(event.replyToken, [welcomeMessage], ACCESS_TOKEN);
}

