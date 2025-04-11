/**
// richMenuIdをげとする方法
const menus = await client.getRichMenuList();

// 返ってくる配列
[
  {
    "richMenuId": "richmenu-xxxxxxxxxxxxxxxxxxxx",
    "name": "menuA",
    "chatBarText": "メニューA",
    ...
  },
  {
    "richMenuId": "richmenu-yyyyyyyyyyyyyyyyyyyy",
    "name": "menuB",
    "chatBarText": "メニューB",
    ...
  }
]
*/

import { Client } from '@line/bot-sdk';
import { channelAccessToken } from "../lib/env.js";

const client = new Client({
  channelAccessToken
});

export async function deleteRichMenusAndAliases() {
  try {
    const menus = await client.getRichMenuList();

    if (!menus || menus.length === 0) {
      console.log('📭 リッチメニューは登録されていません');
      return;
    }

    console.log(`📋 取得したリッチメニュー数: ${menus.length}`);
    menus.forEach((menu, index) => {
      console.log(`No.${index + 1}`);
      console.log(`  richMenuId  : ${menu.richMenuId}`);
      console.log(`  name        : ${menu.name}`);
      console.log(`  chatBarText : ${menu.chatBarText}`);
      console.log('--------------------------');
    });

    try {
      await client.setDefaultRichMenu(null);
      console.log('🚫 デフォルトリッチメニューを解除しました');
    } catch (error) {
      console.warn('⚠ デフォルト解除エラー:', error.message);
    }

    for (const aliasId of ['switch-to-a', 'switch-to-b']) {
      try {
        await client.deleteRichMenuAlias(aliasId);
        console.log(`❌ エイリアス '${aliasId}' を削除しました`);
      } catch (e) {
				if (e.statusCode !== 404) {
					throw e; // ← 404 以外は本当のエラーだから投げる
				} else {
					console.warn("⚠ switch-to-a/switch-to-b は存在しなかったのでスキップしました");
				}
      }
    }

    for (const menu of menus) {
      try {
        await client.deleteRichMenu(menu.richMenuId);
        console.log(`🧹 リッチメニュー削除成功: ${menu.richMenuId}`);
      } catch (error) {
        console.error(`❌ リッチメニュー削除失敗: ${menu.richMenuId}`, error.message);
      }
    }

    console.log('✅ すべてのリッチメニューとエイリアスを削除しました');

  } catch (error) {
    console.error('❌ リッチメニュー削除全体エラー:', error.message);
  }
}
