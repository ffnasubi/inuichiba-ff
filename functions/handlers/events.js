// functions/handlers/events.js
// ✅ 最新版：events.js（.then → await / catch に統一、ログ抑制付き）

const { saveUserProfileAndWrite } = require("../lib/saveUserInfo.js");
const { sendReplyMessage, getUserProfile } = require("../lib/lineApiHelpers.js");
const { textMessages, mediaMessages, lineQRMessages, textTemplates, emojiMap } = require("../richmenu-manager/data/messages.js");
const messages = require("../richmenu-manager/data/messages.js");


// ///////////////////////////////////////////
// eventタイプで処理を振り分ける
async function handleEvent(event, ACCESS_TOKEN) {
  
  const { isProd } = require("../lib/env.js");

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
      if (!isProd) console.log("🔕 ブロックされました:", event.source?.userId);
      break;

    case 'join':
      await handleJoinEvent(event, ACCESS_TOKEN);
      break;

    case 'leave':
      if (!isProd) console.log("🚪 グループから削除されました:", event.source?.groupId || event.source?.roomId);
      break;

    case 'memberJoined':
      if (!isProd) console.log("👧 誰かがグループに参加しました:", event.source?.groupId || event.source?.roomId);
      break;

    case 'memberLeft':
      if (!isProd) console.log("👋 誰かがグループを退出しました:", event.source?.groupId || event.source?.roomId);
      break;

    default:
      // 未処理イベントだけ本番でも出してみる
      // 多すぎたら対応するか無視するかログを抑制する
      console.log("❓ 未処理イベントタイプ:", event.type);
  }
}


// ///////////////////////////////////////////
// followイベントの処理（書き込みはあとから実行）
async function handleFollowEvent(event, ACCESS_TOKEN) {
  const userId = event.source?.userId;
  const groupId = event.source?.groupId || null;
  const { isProd } = require("../lib/env.js");

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
    if (!isProd) console.warn(`⚠️ follow絵文字メッセージの構築失敗: ${error.message}`);
    message = { type: "text", text: "エラーが発生しました。" };
  }

  await sendReplyMessage(event.replyToken, [message], ACCESS_TOKEN);

  // --- 書き込みはあとで非同期に（UI優先！）
  // 有償を避けるため follow eventしか書き込まない
  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
      if (!isProd) console.log("✅ Supabase 書き込み完了 (follow)");
    } catch (err) {
      if (!isProd) console.warn("⚠️ follow 書き込み失敗:", err.message);
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
  const { isProd } = require("../lib/env.js");

  if (userId && !isProd) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      if (!isProd) console.log("⚠️ message書き込み失敗:", err.message);
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
  const { isProd } = require("../lib/env.js");
  
  if (userId && !isProd) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      if (!isProd) console.log("⚠️ postback書き込み失敗:", err.message);
    }
  }
	
}


// ///////////////////////////////////////////
// リッチメニュータップのバッチ処理
async function handleRichMenuTap(data, replyToken, ACCESS_TOKEN) {
  let messages = [];
  const { isProd } = require("../lib/env.js");

  if (!isProd) console.log("🔍 postback data:", data, "（型:", typeof data, "）");

  if (mediaMessages[data]) {
    messages = mediaMessages[data];
  } else if (textMessages[data]) {
    messages = textMessages[data];
  } else if (data == "tap_richMenuA5") {
    await setParkCarouselMessage(replyToken, ACCESS_TOKEN);
    return;
  } else if (data == "tap_richMenuA2") {
    await setMannerCarouselMessage(replyToken, ACCESS_TOKEN);
    return;
  }
    
  try {
    if (textTemplates[data]) {
      const emojiTextMessage = buildEmojiMessage(data, "");
      messages.push(emojiTextMessage);
    }
  } catch (error) {
    if (!isProd) console.warn(`⚠️ Postback絵文字メッセージの構築失敗: ${error.message}`);
  }

  if (messages.length === 0) {
    if (!isProd) console.warn(`⚠️ Postbackで情報が見つかりませんでした: ${data.toString()}`);
  }

  if (messages.length > 0) {
    if (!isProd) {
      console.log("Reply Token:", replyToken);
      console.log("送信メッセージ:", JSON.stringify(messages, null, 2));
    }

    await sendReplyMessage(replyToken, messages, ACCESS_TOKEN);
  }
}


// ///////////////////////////////////////////// 
// 駐車場をカルーセルメッセージにして出力する
async function setParkCarouselMessage(replyToken, ACCESS_TOKEN) {
  const textMessage = {
    type: "text",
    text: messages.msgA5
  };

  const { baseDir } = require("../lib/env.js");

  const flex_message1 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: `${baseDir}carousel/cPark1_baseline.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/cPark1detail_v2.jpg`
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
          url: `${baseDir}carousel/cPark2_baseline2.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/cPark2detail_v2.jpg`
          }
        },
        {
          type: "text",
          text: "イベント会場",
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
          url: `${baseDir}carousel/cPark3_v2.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/cPark3detail_v2.jpg`
          }
        },
        {
          type: "text",
          text: "無料駐車場注意点",
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
    altText: "駐車場地図", 
    contents: {
      type: "carousel",
      contents: carouselContents
    }
  };
	
  const { isProd } = require("../lib/env.js");

  if (!isProd) {
    console.log("📦 Flex Message 中身:", JSON.stringify(flexMessage, null, 2));
    console.log("🚀 実際に送るメッセージ:", [textMessage, flexMessage]);
  }

  await sendReplyMessage(replyToken, [textMessage, flexMessage], ACCESS_TOKEN);
}


// ///////////////////////////////////////////// 
// GOOD MANNERSをカルーセルメッセージにして出力する
async function setMannerCarouselMessage(replyToken, ACCESS_TOKEN) {
  const textMessage = {
    type: "text",
    text: "イベントを楽しむためのご来場マナーと注意事項をご確認ください"
  };
  
  const flex_message1 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📌 ご来場時のお願い",
          weight: "bold",
          size: "xl",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA21,
          wrap: true,
          size: "lg"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"  // 薄いグリーン
      }
    }
  };

  const flex_message2 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "🐾 ワンちゃんとの過ごし方",
          weight: "bold",
          size: "xl",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA22,
          wrap: true,
          size: "lg"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFF3E0"  // 薄いオレンジ
      }
    }
  };

  const flex_message3 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "🚫 立ち話・撮影のマナー",
          weight: "bold",
          size: "xl",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA23,
          wrap: true,
          size: "lg"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"  // 薄いグリーン（修正済）
      }
    }
  };

  const flexMessage = {
    type: "flex",
    altText: "グッドマナー",
    contents: {
      type: "carousel",
      contents: [flex_message1, flex_message2, flex_message3]
    }
  };

  const { isProd } = require("../lib/env.js");

  if (!isProd) {
    console.log("📦 Flex Message 中身:", JSON.stringify(flexMessage, null, 2));
    console.log("🚀 実際に送るメッセージ:", [textMessage, flexMessage]);
  }

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
  const { isProd } = require("../lib/env.js");
  
  if (!isProd) {
    console.log("💡 placeholderCount ($の数):", placeholderCount);
    console.log("🔢 emojiList.length:", emojiList ? emojiList.length : 0);
  }

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

  if (!isProd) {
    console.log("📦 最終構築される emojis 配列:", emojis);
    console.log("✅ 最終返却メッセージ:", {
      type: "text",
      text: rawText,
      emojis: emojis
    });
  }

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
  const { isProd } = require("../lib/env.js");

  if (!isProd) console.log("👋 joinイベント発生！グループまたはルームID:", groupId);

  const welcomeMessage = { type: "text", text: messages.msgJoin };

  await sendReplyMessage(event.replyToken, [welcomeMessage], ACCESS_TOKEN);
}

module.exports = { handleEvent };
