// batchCreateRichMenu.js（CLIで実行用）
// 実行方法
//  cd functions
//  node richmenu-manager/batchCreateRichMenu.js

require('./env-loader.js'); 
const { deleteRichMenusAndAliases } = require('./deleteAllRichMenus.js');
const { handleRichMenu } = require('./richMenuHandler.js');


// メイン処理
async function main() {
  console.log("🔁 リッチメニュー初期化開始");

  await deleteRichMenusAndAliases();
  console.log("🗑️ 既存リッチメニュー削除完了");

  const { channelAccessToken } = require('../lib/env.js');

  await handleRichMenu(channelAccessToken);
  console.log("✅ リッチメニュー再作成完了");
}

main();
