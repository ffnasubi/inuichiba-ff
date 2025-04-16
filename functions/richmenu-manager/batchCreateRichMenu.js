// batchCreateRichMenu.js（CLIで実行用）
// 実行方法
//  cd functions
//  node richmenu-manager/batchCreateRichMenu.js

const { deleteRichMenusAndAliases } = require('./deleteAllRichMenus.js');
const { handleRichMenu } = require('./richMenuHandler.js');


// メイン処理
async function main() {
  const { channelAccessToken, isProd } = require('../lib/env.js');
  if (!isProd) console.log("🔁 リッチメニュー初期化開始");

  await deleteRichMenusAndAliases();
  if (!isProd) console.log("🗑️ 既存リッチメニュー削除完了");

  await handleRichMenu(channelAccessToken);
  if (!isProd) console.log("✅ リッチメニュー再作成完了");
}

main();
