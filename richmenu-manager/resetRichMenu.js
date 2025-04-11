// 実行コマンド→ node richmenu-manager/resetRichMenu.js

import 'dotenv/config';
import { deleteRichMenusAndAliases } from './deleteAllRichMenus.js';
import { handleRichMenu } from './richMenuHandler.js';
import { channelAccessToken } from "../lib/env.js";

// メイン処理
async function main() {
  console.log("🔁 リッチメニュー初期化開始");

  await deleteRichMenusAndAliases();
  console.log("🗑️ 既存リッチメニュー削除完了");

  await handleRichMenu(channelAccessToken);
  console.log("✅ リッチメニュー再作成完了");
}

main();
