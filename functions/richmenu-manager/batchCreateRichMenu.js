// batchCreateRichMenu.js（CLIで実行用）
// 実行方法
//   cd d:\nasubi\inuichiba_ff
//   .\run-richmenu.ps1 -env ffdev(既定値)  --- 開発環境用
//   .\run-richmenu.ps1 -env ffprod       	--- 本番環境用

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
