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

const { Client } = require('@line/bot-sdk');
const { channelAccessToken } = require('../lib/env.js');

const client = new Client({
  channelAccessToken
});

async function deleteRichMenusAndAliases() {
  const { isProd } = require("../lib/env.js");
  try {
    const menus = await client.getRichMenuList();

    if (!menus || menus.length === 0) {
      if (!isProd) console.log('📭 リッチメニューは登録されていません');
      return;
    }

    if (!isProd) console.log(`📋 取得したリッチメニュー数: ${menus.length}`);
    menus.forEach((menu, index) => {
      if (!isProd)  {
        console.log(`No.${index + 1}`);
        console.log(`  richMenuId  : ${menu.richMenuId}`);
        console.log(`  name        : ${menu.name}`);
        console.log(`  chatBarText : ${menu.chatBarText}`);
        console.log('--------------------------');
      }
    });

    try {
      await client.setDefaultRichMenu(null);
      if (!isProd) console.log('🚫 デフォルトリッチメニューを解除しました');
    } catch (error) {
      if (!isProd) console.warn('⚠ デフォルト解除エラー:', error.message);
    }

    for (const aliasId of ['switch-to-a', 'switch-to-b']) {
      try {
        await client.deleteRichMenuAlias(aliasId);
        if (!isProd) console.log(`❌ エイリアス '${aliasId}' を削除しました`);
      } catch (e) {
				if (e.statusCode !== 404) {
					throw e; // ← 404 以外は本当のエラーだから投げる
				} else {
					if (!isProd) console.warn("⚠ switch-to-a/switch-to-b は存在しなかったのでスキップしました");
				}
      }
    }

    for (const menu of menus) {
      try {
        await client.deleteRichMenu(menu.richMenuId);
        if (!isProd) console.log(`🧹 リッチメニュー削除成功: ${menu.richMenuId}`);
      } catch (error) {
        if (!isProd) console.error(`❌ リッチメニュー削除失敗: ${menu.richMenuId}`, error.message);
      }
    }

    if (!isProd) console.log('✅ すべてのリッチメニューとエイリアスを削除しました');

  } catch (error) {
    console.error('❌ リッチメニュー削除全体エラー:', error.message);
  }
}

module.exports = { deleteRichMenusAndAliases };
