// functions/handlers/events.js
// ✅ 最新版：events.js（.then → await / catch に統一、ログ抑制付き）

const { saveUserProfileAndWrite } = require("../lib/saveUserInfo.js");
const { sendReplyMessage, getUserProfile } = require("../lib/lineApiHelpers.js");
const { keywordMap, textMessages, mediaMessages, lineQRMessages, textTemplates, emojiMap } = require("../richmenu-manager/data/messages.js");
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
  const userId = event.source?.userId ?? null;
  const groupId =
    event.source?.type === "group" ? event.source.groupId :
    event.source?.type === "room"  ? event.source.roomId :
    null;
  const sourceType = event.source?.type ?? null;  // 'user' | 'group' | 'room'
  const eventType = "follow";
  
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
    } catch (err) {
      if (!isProd) console.warn(`⚠️ ${eventType}書き込み失敗: 種別=${sourceType}`, err.message);
    }
  }

}


// ///////////////////////////////////////////
// messageイベントの処理（書き込みは後ろで非同期）
async function handleMessageEvent(event, ACCESS_TOKEN) {
	const userId = event.source?.userId ?? null;
	const sourceType = event.source?.type ?? null;  // 'user' | 'group' | 'room'
  const groupId =
    event.source?.type === "group" ? event.source.groupId :
    event.source?.type === "room"  ? event.source.roomId :
    null;
  const data = event.message.text;
  const eventType = "message";
	let message = [];
	
	// LINE公式アカウントの「自動応答対象ワード」はBotが代わりに返信
	if (data === "QRコード" || data === "友だち追加") {
    message = lineQRMessages;
    await sendReplyMessage(event.replyToken, message, ACCESS_TOKEN);
  } 
	// グループ or ルームからのメッセージは、LINE自動応答メッセージのみBotの代わりに返信
	// 他は完全に無視
	else if (sourceType === "group" || sourceType === "room") {
    return;
  }
  // 以下は「個人チャット」で、自動応答以外のメッセージ
	else if (data === "ワイワイ") {
    message = [{ type: "text", text: messages.msgY }];
    await sendReplyMessage(event.replyToken, message, ACCESS_TOKEN);
  }
  // keywordMap に一致するかどうかで分岐
  else if (keywordMap[data]) {
    const key = keywordMap[data];  // 例: "tap_richMenuA1"
    await handleRichMenuTap(key, event.replyToken, ACCESS_TOKEN);  // ✅ postbackと共通処理に流す
  } 
  // 上記すべてに該当しない場合
	else {
    message = [{ type: "text", text: messages.msgPostpone }];
    await sendReplyMessage(event.replyToken, message, ACCESS_TOKEN);
  }
	
  // --- Supabase書き込みはメッセージ送信後、後回しに実行（非同期）
  const { isProd } = require("../lib/env.js");

  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      if (!isProd) console.warn(`⚠️ ${eventType}書き込み失敗: 種別=${sourceType}`, err.message);
    }
  }
	
}


// ///////////////////////////////////////////
// リッチメニュータップのバッチ処理
async function handleRichMenuTap(data, replyToken, ACCESS_TOKEN) {
  let messages = [];
  let carouselFlg = false;
  let textMessage, flexMessage;

  const { isProd } = require("../lib/env.js");
  
  if (!isProd) console.log("🔍 message data:", data, "（型:", typeof data, "）");

  if (mediaMessages[data]) {
    messages = mediaMessages[data];
  } else if (textMessages[data]) {
    messages = textMessages[data];
  } else if (data == "tap_richMenuA2") {
    carouselFlg = true;
    [textMessage, flexMessage] = setMannerCarouselMessage();
  } else if (data == "tap_richMenuA4") {
    carouselFlg = true;
    [textMessage, flexMessage] = setDogRunCarouselMessage();
  } else if (data == "tap_richMenuA5") {
    carouselFlg = true;
    [textMessage, flexMessage] = setDogRunCarouselMessage2();
  } else if (data == "tap_richMenuA6") {
    carouselFlg = true;
    [textMessage, flexMessage] = setParkingCarouselMessage();
  } else if (data == "tap_richMenuA7") {
    carouselFlg = true;
    [textMessage, flexMessage] = setPandRCarouselMessage();
  } else if (data == "tap_richMenuB5") {
    carouselFlg = true;
    [textMessage, flexMessage] = setMapCarouselMessage();
  }

  try {
    if (textTemplates[data]) {
      const emojiTextMessage = buildEmojiMessage(data, "");
      messages.push(emojiTextMessage);
    }
  } catch (error) {
    if (!isProd) console.warn(`⚠️ message 絵文字メッセージの構築失敗: ${error.message}`);
  }

  // 配列で初期化してればいきなり0かと聞いても大丈夫(配列が0個と返すから)
  if (messages.length > 0 && !isProd) {
    console.log("Reply Token:", replyToken);
    console.log("送信メッセージ:", JSON.stringify(messages, null, 2));
  }

  if (carouselFlg) {
    await sendReplyMessage(replyToken, [textMessage, flexMessage], ACCESS_TOKEN);
  } else {
    await sendReplyMessage(replyToken, messages, ACCESS_TOKEN);
  }

}


// ///////////////////////////////////////////
// メニュー切り替え時に通知されるpostback処理を行う
async function handlePostbackEvent(event, ACCESS_TOKEN) {
  const userId = event.source?.userId ?? null;
  const groupId =
    event.source?.type === "group" ? event.source.groupId :
    event.source?.type === "room"  ? event.source.roomId :
    null;
  const sourceType = event.source?.type ?? null;  // 'user' | 'group' | 'room'
  const data = event.postback.data;
  const eventType = "postback";

  const { isProd } = require("../lib/env.js");
    
  // タブ切り替え。ログだけ出す(安定したらログ不要になるかな？)
  if (data === "change to A" || data === "change to B") {
    if (!isProd) console.log("🔁 タブ切り替え postback 受信（許可）:", data);
    return;
  }

  // その他のpostbackは明示的に禁止
  console.error("⚠️ 想定外の postback を受信しました:", event);  
}


// ///////////////////////////////////////////
// joinイベント（グループやルームに招待されたときの挨拶）
async function handleJoinEvent(event, ACCESS_TOKEN) {
  const userId = event.source?.userId ?? null;
  const groupId =
    event.source?.type === "group" ? event.source.groupId :
    event.source?.type === "room"  ? event.source.roomId :
    null;
  const sourceType = event.source?.type ?? null;  // 'user' | 'group' | 'room'
  const eventType = "join";
  
  const { isProd } = require("../lib/env.js");
    
  const welcomeMessage = { type: "text", text: messages.msgJoin };
  await sendReplyMessage(event.replyToken, [welcomeMessage], ACCESS_TOKEN);

  if (userId) {
    try {
      await saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN);
    } catch (err) {
      if (!isProd) console.warn(`⚠️ ${eventType}書き込み失敗: 種別=${sourceType}`, err.message);
    }
  }

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



// ///////////////////////////////////////////// 
// GOOD MANNERSをカルーセルメッセージにする
function setMannerCarouselMessage() {
  const textMessage = {
    type: "text",
    text: messages.msgA2
  };
  
  const { baseDir } = require("../lib/env.js");

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
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}rules/rules_arrival.jpg`
          },
          style: "secondary",
          color: "#C8E6C9", // グリーン（ボタン）
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9" // 薄いグリーン（バブル背景）
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
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}rules/rules_dog.jpg`
          },
          style: "secondary",
          color: "#FFD180", // オレンジ（ボタン）
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFF3E0" // 薄いオレンジ（バブル背景）
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
          text: "📌 立ち話・撮影のマナー",
          weight: "bold",
          size: "xl",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA23,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}rules/rules_manner.jpg`
          },
          style: "secondary",
          color: "#C8E6C9", // グリーン（ボタン）
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9" // 薄いグリーン（バブル背景）
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

  return [textMessage, flexMessage];
}


// ///////////////////////////////////////////// 
// ドッグランの留意事項をカルーセルメッセージにする(テキスト版)
function setDogRunCarouselMessage() {
  const textMessage = {
    type: "text",
    text: messages.msgA4
  };

  const { baseDir } = require("../lib/env.js");

  const flex_message1 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📌  ドッグランをご利用いただくにあたり",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: "ドッグラン専用入場リストバンドがありませんとご利用できません",
          color: "#FF0000",
          size: "md",
          wrap: true
        },
        {
          type: "text",
          text: "料金：1頭 500円",
          weight: "bold",
          size: "md",
          wrap: true
        },
        {
          type: "text",
          text: "ご利用になる皆さまには皆さまが安全に楽しくご利用いただくためのルールがございますのでご確認をお願い申し上げます。",
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun1.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
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
          text: "🐾 ドッグランをご利用いただくにあたり【利用規約】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA41,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun2_v1.jpg`
          },
          style: "secondary",
          color: "#ffd180",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#fff3E0"
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
          text: "🐾 ドッグランをご利用いただくにあたり【利用規約】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA42,
          size: "md",
          color: "#FF0000",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun3.jpg`
          },
          style: "secondary",
          color: "#FFD180",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFF3E0"
      }
    }
  };
  
  const flex_message4 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "🐾 ドッグランをご利用いただくにあたり【利用規約】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA43,
          size: "md",
          color: "#FF0000",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun4.jpg`
          },
          style: "secondary",
          color: "#FFD180",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFF3E0"
      }
    }
  };

  const flex_message5 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📌 ドッグランをご利用いただくにあたり【注意事項】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA44,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun_warning1.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };
  
  const flex_message6 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📌 ドッグランをご利用いただくにあたり【注意事項】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA45,
          color: "#FF0000",
          size: "md",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA46,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun_warning2.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };

  const flex_message7 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📌 ドッグランをご利用いただくにあたり【注意事項】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA47,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun_warning3.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };
  
  const flex_message8 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "📋 必要な証明書",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "image",
          url: `${baseDir}carousel/dogRun2.jpg`,
          size: "full",
          aspectMode: "fit",
          margin: "md"
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}carousel/dogRun2.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };
  
  const flex_message9 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "🐾 犬種によるドッグランの分け方【小型犬ゾーン】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA48,
          size: "sm",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogtypes_small_v1.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };
  
  const flex_message10 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      spacing: "xl",
      contents: [
        {
          type: "text",
          text: "🐾 犬種によるドッグランの分け方【全犬種ゾーン】",
          weight: "bold",
          size: "lg",
          align: "center",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA49,
          size: "sm",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogtypes_all.jpg`
          },
          style: "secondary",
          color: "#C8E6C9",
          height: "sm"
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#E8F5E9"
      }
    }
  };
 
  
  const carouselContents = [flex_message1, flex_message2, flex_message3, flex_message4, flex_message5, 
                            flex_message6, flex_message7, flex_message8, flex_message9, flex_message10];

  const flexMessage = {
    type: "flex",
    altText: "ドッグラン", 
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

  return [textMessage, flexMessage];
}
  

// ///////////////////////////////////////////// 
// ドッグランの留意事項をカルーセルメッセージにして出力する(図を2分割した版)
function setDogRunCarouselMessage2() {
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
          url: `${baseDir}carousel/dogRun11.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/dogRun11.jpg`
          }
        },
        {
          type:  "button",
          style: "primary",
          color: "#A5D6A7",
          action: {
            type: "uri",
            label: "拡大版はこちら🔎",
            uri: `${baseDir}carousel/dogRun11.jpg`
          }
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
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
          url: `${baseDir}carousel/dogRun12.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/dogRun12.jpg`
          }
        },
        {
          type:  "button",
          style: "primary",
          color: "#A5D6A7",
          action: {
            type: "uri",
            label: "拡大版はこちら🔎",
            uri: `${baseDir}carousel/dogRun12.jpg`
          }
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
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
          url: `${baseDir}carousel/dogRun2.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/dogRun2.jpg`
          }
        },
        {
          type:  "button",
          style: "primary",
          color: "#A5D6A7",
          action: {
            type: "uri",
            label: "拡大版はこちら🔎",
            uri: `${baseDir}carousel/dogRun2.jpg`
          }
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const flex_message4 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: `${baseDir}carousel/dogRun31.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/dogRun31.jpg`
          }
        },
        {
          type:  "button",
          style: "primary",
          color: "#A5D6A7",
          action: {
            type: "uri",
            label: "拡大版はこちら🔎",
            uri: `${baseDir}carousel/dogRun31.jpg`
          }
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const flex_message5 = {
    type: "bubble",
    body: {
      type: "box",
      layout: "vertical",
      contents: [
        {
          type: "image",
          url: `${baseDir}carousel/dogRun32.jpg`,
          size: "full",
          aspectRatio: "1:1",
          aspectMode: "fit",
          action: {
            type: "uri",
            uri: `${baseDir}carousel/dogRun32.jpg`
          }
        },
        {
          type:  "button",
          style: "primary",
          color: "#A5D6A7",
          action: {
            type: "uri",
            label: "拡大版はこちら🔎",
            uri: `${baseDir}carousel/dogRun32.jpg`
          }
        }
      ]
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const carouselContents = [flex_message1, flex_message2, flex_message3, flex_message4, flex_message5];

  const flexMessage = {
    type: "flex",
    altText: "ドッグラン", 
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

  return [textMessage, flexMessage];
}


// ///////////////////////////////////////////// 
// PARKING(駐車場及びアクセス方法)をカルーセルメッセージにする
function setParkingCarouselMessage() {
  const textMessage = {
    type: "text", 
    text: messages.msgA61 + "\n\n\n" + messages.msgA62 + "\n\n\n" + messages.msgA63
  };

  const { baseDir } = require("../lib/env.js");

  const flex_message1 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/parking1.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/parking1.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message2 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/parking2.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/parking2.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };


  const carouselContents = [flex_message1, flex_message2];

  const flexMessage = {
    type: "flex",
    altText: "Parking", 
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

  return [textMessage, flexMessage];
}


// ///////////////////////////////////////////// 
// P&R(パークアンドライド)をカルーセルメッセージにする
function setPandRCarouselMessage() {
  const textMessage = {
    type: "text", 
    text: messages.msgA7
  };

  const { baseDir } = require("../lib/env.js");

  const flex_message1 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr1.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr1.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message2 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr2.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr2.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message3 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr3.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr3.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message4 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr4.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr4.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message5 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr5.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr5.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message6 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr6.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr6.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };

  const flex_message7 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/pandr7.jpg`,
      size: "full",
      aspectRatio: "3:4",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/pandr7.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#75BF82"
      }
    }
  };


  const carouselContents = [flex_message1, flex_message2, flex_message3, flex_message4, flex_message5, flex_message6, flex_message7];

  const flexMessage = {
    type: "flex",
    altText: "Parking", 
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

  return [textMessage, flexMessage];
}


// ///////////////////////////////////////////// 
// MAP(会場マップ/ショップリスト)をカルーセルメッセージにする
function setMapCarouselMessage() {
  const textMessage = {
    type: "text",
    text: messages.msgB5
  };

  const { baseDir } = require("../lib/env.js");

  const flex_message1 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/mapAll.jpg`,
      size: "full",
      aspectRatio: "4:3",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/mapAll.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const flex_message2 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/map1.jpg`,
      size: "full",
      aspectRatio: "4:3",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/map1.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const flex_message3 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/map2.jpg`,
      size: "full",
      aspectRatio: "4:3",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/map2.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };

  const flex_message4 = {
    type: "bubble",
    hero: {
      type: "image",
      url: `${baseDir}carousel/map3.jpg`,
      size: "full",
      aspectRatio: "4:3",
      aspectMode: "cover",
      action: {
        type: "uri",
        uri: `${baseDir}carousel/map3.jpg`
      }   
    },
    styles: {
      body: {
        backgroundColor: "#FFFFFF"
      }
    }
  };


  const carouselContents = [flex_message1, flex_message2, flex_message3, flex_message4];

  const flexMessage = {
    type: "flex",
    altText: "MAP", 
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

  return [textMessage, flexMessage];
}


module.exports = { handleEvent };

