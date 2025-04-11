// 開発時のみ実行 node richmenu-manager/testRichMenuLink.js
// テストで個人ユーザーにだけリッチメニューをリンクしたいときに、
// LINEのユーザーIDとメニュー名を .env.xx..xx にセットしておいて手動実行したいとき使う
// 今は使ってないのでコメントアウトしてるの
/*

// richmenu-manager/testRichMenuLink.js

import 'dotenv/config';
import line from '@line/bot-sdk';
import { channelAccessToken, channelSecret, myLineUserId, targetMenuName } from "../lib/env.js";

const client = new line.Client({
  channelAccessToken,
  channelSecret,
});


// richMenu名からrichMenuIdを取得する関数
async function getRichMenuIdByName(targetName) {
  const menus = await client.getRichMenuList();

  console.log('📋 登録済みリッチメニュー一覧:');
  menus.forEach(menu => {
    console.log(`- ${menu.name}: ${menu.richMenuId}`);
  });

  const found = menus.find(menu => menu.name === targetName);
  if (!found) {
    throw new Error(`❌ メニュー「${targetName}」が見つかりませんでした`);
  }

  return found.richMenuId;
}

async function linkRichMenuByName() {
  try {
    const richMenuId = await getRichMenuIdByName(targetMenuName);

    await client.unlinkRichMenuFromUser(myLineUserId);
    console.log('✅ unlink 成功');

    await client.linkRichMenuToUser(myLineUserId, richMenuId);
    console.log(`✅ リッチメニュー「${targetMenuName}」をリンクしました`);
  } catch (err) {
    console.error('❌ エラー:', err.originalError?.response?.data || err);
  }
}
*/
