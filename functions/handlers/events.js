// functions/handlers/events.js
// ✅ 最新版：events.js（.then → await / catch に統一、ログ抑制付き）

const { saveUserProfileAndWrite } = require("../lib/saveUserInfo.js");
const { sendReplyMessage, getUserProfile } = require("../lib/lineApiHelpers.js");
// const { keywordMap, textMessages, mediaMessages, lineQRMessages, textTemplates, emojiMap } = require("../richmenu-manager/data/messages.js");
const messages = require("../richmenu-manager/data/messages.js");
const getEnv = require("../lib/env.js");


// ///////////////////////////////////////////
// eventタイプで処理を振り分ける
async function handleEvent(event, ACCESS_TOKEN) {
  
  const { isProd } = getEnv();

  switch (event.type) {
    case 'message':
      await handleMessageEvent(event, ACCESS_TOKEN);
      break;

    case 'postback':
      await handlePostbackEvent(event);
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
  const { isProd } = getEnv();

  // --- メッセージ生成＆返信
  const profile = await getUserProfile(userId, ACCESS_TOKEN);
  const displayName = profile?.displayName || null;
  const followText = messages.textTemplates["msgFollow"];
  
  let mBody = (displayName == null || displayName.includes("$"))
    ? followText
    : `${displayName}さん、${followText}`;

  let message;
  try {
    const emojiTextMessage = buildEmojiMessage("msgFollow", mBody);
    message = emojiTextMessage;
  } catch (error) {
    if (!isProd) console.warn(`⚠️ follow 絵文字メッセージの構築失敗: ${error.message}`);
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
    message = messages.lineQRMessages;
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
  else if (messages.keywordMap[data]) {
    const key = messages.keywordMap[data];  // 例: "tap_richMenuA1"
    await handleRichMenuTap(key, event.replyToken, ACCESS_TOKEN);  // ✅ postbackと共通処理に流す
  } 
  // 上記すべてに該当しない場合
	else {
    message = [{ type: "text", text: messages.msgPostpone }];
    await sendReplyMessage(event.replyToken, message, ACCESS_TOKEN);
  }
	
  // --- Supabase書き込みはメッセージ送信後、後回しに実行（非同期）
  const { isProd } = getEnv();

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

  if (messages.mediaMessages[data]) {
    messages = messages.mediaMessages[data];
  } else if (messages.textMessages[data]) {
    messages = messages.textMessages[data];
  } 
  // フレックスメッセージはテキストとフレックスが配列じゃなく展開されてくるので、
  // そのままま全部受け取る
  else if (data == "tap_richMenuA2" || data == "tap_richMenuB2") {
    carouselFlg = true;
    messages = setMannerCarouselMessage();
  } 
  else if (data == "tap_richMenuA3" || data == "tap_richMenuB4") {
    carouselFlg = true;
    messages = setPandRCarouselMessage();
  } 
  else if (data == "tap_richMenuA5") {
    carouselFlg = true;
    messages = setDogRunCarouselMessage();
  } 
  else if (data == "tap_richMenuA6" || data == "tap_richMenuB5") {
    carouselFlg = true;
    messages = setMapCarouselMessage();
  } 
  else if (data == "tap_richMenuA7" || data == "tap_richMenuB6") {
    carouselFlg = true;
    messages = setParkingCarouselMessage();
  }

  
  const { isProd } = getEnv();

  try {
    if (messages.textTemplates[data]) {
      const emojiTextMessage = buildEmojiMessage(data, "");
      messages.push(emojiTextMessage);
    }
  } catch (error) {
    if (!isProd) console.warn(`⚠️ message 絵文字メッセージの構築失敗: ${error.message}`);
  }

  
  // カルーセルメッセージか？
  if (carouselFlg) {
    // フレックスメッセージ部分だけを入れる
    const flexMsg = messages.find(m => m.type === "flex");

    if (flexMsg) {
      if (!isProd) console.log("📦 Flex Message 部分:", JSON.stringify(flexMsg, null, 2));
    } else {
      console.error("❌ Flex Message が見つかりません（type:flex がありません）");
    }
    if (!isProd) console.log("🚀 送信するメッセージ一覧:", JSON.stringify(messages, null, 2));
  } else {
    // 配列で初期化してればいきなり0かと聞いても大丈夫(配列が0個と返すから)
    if (messages.length > 0 && !isProd) {
      console.log("Reply Token:", replyToken);
      console.log("送信メッセージ:", JSON.stringify(messages, null, 2));
    }
  }


  // 送信(書き込みは呼び出し側で行う)
  await sendReplyMessage(replyToken, messages, ACCESS_TOKEN);

}


// ///////////////////////////////////////////
// メニュー切り替え時に通知されるpostback処理を行う
async function handlePostbackEvent(event) {
  const data = event.postback.data;

  const { isProd } = getEnv();
    
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
  
  const { isProd } = getEnv();
    
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
  let rawText = messages.textTemplates[templateKey];
  const emojiList = messages.emojiMap[templateKey];

  if (templateKey === "msgFollow") {
    rawText = mBody;
  }

  if (!rawText) {
    throw new Error(`テキストテンプレートが見つかりません: ${templateKey}`);
  }

  const placeholderCount = (rawText.match(/\$/g) || []).length;
  const { isProd } = getEnv();
    
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


// ----------- ↓ ここからカルーセルメッセージたち ↓ -----------
// ///////////////////////////////////////////// 
// GOOD MANNERSをカルーセルメッセージにする
function setMannerCarouselMessage() {
  // ✅【超重要】カルーセル用のテキストを設定するときは必ずコレ！
  // ・messages.js から取るときは → ✅ messages.msgXXX にすること！
  // ・❌ msgXXX だけだと100%エラーになります（💥ReferenceError）
  // ・そのエラー、原因特定が地獄になるよー（経験者は語る）
  //   → コピペ時に必ず確認！名前違ったら即エラー直撃！
  // 
  // ✅ 正しい書き方：messages.msgA61
  messages.textMessage = [
    { type: "text", text: messages.msgA20 }
  ];
  
  const { baseDir } = getEnv();

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

  
  // textMessage が配列ならそのまま使う、単体なら配列に包む(今は全部配列なので不要)  
  // const textMessagesArray = Array.isArray(textMessage) ? textMessage : [textMessage];
  
  // ✅ テキストの配列を展開して、
  // 最終的に [ text, text, ～, flex ] (全体を配列にする)形式にまとめて返す
  return [...messages.textMessage, flexMessage];

}


// ///////////////////////////////////////////// 
// ドッグランの留意事項をカルーセルメッセージにする(テキスト版)
function setDogRunCarouselMessage() {
  // ✅【超重要】カルーセル用のテキストを設定するときは必ずコレ！
  // ・messages.js から取るときは → ✅ messages.msgXXX にすること！
  // ・❌ msgXXX だけだと100%エラーになります（💥ReferenceError）
  // ・そのエラー、原因特定が地獄になるよー（経験者は語る）
  //   → コピペ時に必ず確認！名前違ったら即エラー直撃！
  // 
  // ✅ 正しい書き方：messages.msgA61
  messages.textMessage = [
    { type: "text", text: messages.msgA50 }
  ];

  const { baseDir } = getEnv();

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
          text: messages.msgA51,
          size: "md",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun2.jpg`
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
          text: messages.msgA52,
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
          text: messages.msgA53,
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
          text: messages.msgA54,
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
          text: messages.msgA55,
          color: "#FF0000",
          size: "md",
          wrap: true
        },
        {
          type: "text",
          text: messages.msgA56,
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
          text: messages.msgA57,
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
          url: `${baseDir}dogrun/view_dogrun5.jpg`,
          size: "full",
          aspectMode: "fit",
          margin: "md"
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogrun5.jpg`
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
          text: messages.msgA58,
          size: "sm",
          wrap: true
        },
        {
          type: "button",
          action: {
            type: "uri",
            label: "拡大版はこちら",
            uri: `${baseDir}dogrun/view_dogtypes_small.jpg`
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
          text: messages.msgA59,
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
	
  
  // textMessage が配列ならそのまま使う、単体なら配列に包む(今は全部配列なので不要)  
  // const textMessagesArray = Array.isArray(textMessage) ? textMessage : [textMessage];
  
  // ✅ テキストの配列を展開して、
  // 最終的に [ text, text, ～, flex ] (全体を配列にする)形式にまとめて返す
  return [...messages.textMessage, flexMessage];

}
  

// ///////////////////////////////////////////// 
// PARKING(駐車場及びアクセス方法)をカルーセルメッセージにする
function setParkingCarouselMessage() {
  // ✅【超重要】カルーセル用のテキストを設定するときは必ずコレ！
  // ・messages.js から取るときは → ✅ messages.msgXXX にすること！
  // ・❌ msgXXX だけだと100%エラーになります（💥ReferenceError）
  // ・そのエラー、原因特定が地獄になるよー（経験者は語る）
  //   → コピペ時に必ず確認！名前違ったら即エラー直撃！
  // 
  // ✅ 正しい書き方：messages.msgA61
  messages.textMessage =  [
    { type: "text", text: messages.msgA70 },
    { type: "text", text: messages.msgA71 },
    { type: "text", text: messages.msgA72 }
  ];
  
  const { baseDir } = getEnv();

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
	
  
  // textMessage は常に [ {type: text, ～}, {type: text, ～} ] (配列)形式で送ってくる
  // ひとつのメッセージでもいったん配列形式にする
  // そして...(スプレッド構文)をつけることで、textMessage(配列)の内容を展開する
  // 例えばmessages.msga61, messages.msga62, messages.msga63, flexMessage 
  // のように展開して順番で受け手側に渡すことができる 
  // 後はLINEがテキストならテキスト処理、カルーセルならカルーセル処理を行うだけ

  // textMessage が配列ならそのまま使う、単体なら配列に包む
  // const textMessagesArray = Array.isArray(textMessage) ? textMessage : [textMessage];
  
  // ✅ テキストの配列を展開して、
  // 最終的に [ text, text, ～, flex ] (全体を配列にする)形式にまとめて返す
  return [...messages.textMessage, flexMessage];

}


// ///////////////////////////////////////////// 
// P&R(パークアンドライド)をカルーセルメッセージにする
function setPandRCarouselMessage() {
  // ✅【超重要】カルーセル用のテキストを設定するときは必ずコレ！
  // ・messages.js から取るときは → ✅ messages.msgXXX にすること！
  // ・❌ msgXXX だけだと100%エラーになります（💥ReferenceError）
  // ・そのエラー、原因特定が地獄になるよー（経験者は語る）
  //   → コピペ時に必ず確認！名前違ったら即エラー直撃！
  // 
  // ✅ 正しい書き方：messages.msgA61
  messages.textMessage = [
    { type: "text", text: messages.msgA3 }
  ];

  const { baseDir } = getEnv();

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
	
  
  // textMessage が配列ならそのまま使う、単体なら配列に包む(今は全部配列なので不要)  
  // const textMessagesArray = Array.isArray(textMessage) ? textMessage : [textMessage];
  
  // ✅ テキストの配列を展開して、
  // 最終的に [ text, text, ～, flex ] (全体を配列にする)形式にまとめて返す
  return [...messages.textMessage, flexMessage];

}


// ///////////////////////////////////////////// 
// MAP(会場マップ/ショップリスト)をカルーセルメッセージにする
function setMapCarouselMessage() {
  // ✅【超重要】カルーセル用のテキストを設定するときは必ずコレ！
  // ・messages.js から取るときは → ✅ messages.msgXXX にすること！
  // ・❌ msgXXX だけだと100%エラーになります（💥ReferenceError）
  // ・そのエラー、原因特定が地獄になるよー（経験者は語る）
  //   → コピペ時に必ず確認！名前違ったら即エラー直撃！
  // 
  // ✅ 正しい書き方：messages.msgA61
  messages.textMessage = [
    { type: "text", text: messages.msgA6 }
  ];

  const { baseDir } = getEnv();

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
        backgroundColor: "#E3EEF4"
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
        backgroundColor: "#E3EEF4"
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
        backgroundColor: "#E3EEF4"
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
	
  
  // textMessage が配列ならそのまま使う、単体なら配列に包む(今は全部配列なので不要)  
  // const textMessagesArray = Array.isArray(textMessage) ? textMessage : [textMessage];
  
  // ✅ テキストの配列を展開して、
  // 最終的に [ text, text, ～, flex ] (全体を配列にする)形式にまとめて返す
  return [...messages.textMessage, flexMessage];

}


module.exports = { handleEvent };

