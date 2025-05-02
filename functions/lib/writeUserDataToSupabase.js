// ✅ 外部公開：ユーザーデータをSupabaseに書き込む
const { initSupabaseClient } = require('./supabaseClient.js');


// ✅ 日本時間のタイムスタンプ（先頭0なしのH形式）
function getFormattedJST() {
  const now = new Date();
  const jst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const yyyy = jst.getFullYear();
  const mm = String(jst.getMonth() + 1).padStart(2, '0');
  const dd = String(jst.getDate()).padStart(2, '0');
  const h = jst.getHours();
  const mi = String(jst.getMinutes()).padStart(2, '0');
  const ss = String(jst.getSeconds()).padStart(2, '0');
  return `${yyyy}/${mm}/${dd} ${h}:${mi}:${ss}`;
}

// ✅ オブジェクト形式で引数を受け取り、データベースに書き込む
async function writeUserDataToSupabase({
  groupId,
  userId,
  displayName,
  pictureUrl,
  statusMessage,
  shopName,
  inputData
}) {
  const timestamp = getFormattedJST();
  const safeGroupId = groupId || "default";
  
  let supabaseHolder = {};              // ← client を格納するオブジェクトを定義
  initSupabaseClient(supabaseHolder);   // ← client を初期化(lient を格納（参照渡し）)
  const supabase = supabaseHolder.client;
  const usersTable = supabaseHolder.usersTable;

  const userData = {
      timestamp,
      groupId: safeGroupId,
      userId,
      displayName,
      pictureUrl,
      statusMessage,
      shopName,
      inputData
  };

  // ✅ env.js は Secrets 反映後に require する
  const { isProd } = require('./env.js');

  if (!isProd) {
		console.log("🕐 書き込み開始タイムスタンプ:", timestamp);
    console.log("📦 書き込みデータ:", userData);
  }
    
  try {
    let result;

    // 本番環境(ffprod)では既存レコードがあるか確認し、初回だけ書き込む
    if (isProd) {
      // ✅ 既存チェック（groupId + userId がすでに存在するか）
      const { data: existing, error: selectError } = await supabase
        .from(usersTable)
        .select('userId')
        .eq('groupId', safeGroupId)
        .eq('userId', userId)
        .limit(1);

      if (selectError) {
        // ❌ Supabase 存在確認エラー
        return { error: selectError };
      }

      if (existing && existing.length > 0) {
        // 🟡 Supabase 書き込みスキップ（既存データ）
        return { data: [] }; // ← 書き込みはスキップしたが、成功扱い
      }

      // ✅ 初回のみ insert（conflict の心配なし）
      result = await supabase
        .from(usersTable)
        .insert([userData]);
    
    } 
    // 開発環境(ffdev)では同じデータがあっても何回でも書き込む
    else {
      // ✅ 開発環境は毎回上書きOK
      result = await supabase
        .from(usersTable)
        .upsert([userData], {
          onConflict: ['groupId', 'userId']
      });
    } 
    
    // ✅ 本番でも出す：Supabaseの応答を受けた時点の正確なJS時刻（ISO形式）
    // vercelではそうだったけどFFではcoonsole.logは課金対象なので抑制する
		if (!isProd) console.log("🕐 書き込み完了タイムスタンプ:", getFormattedJST());

    return result; // ← 呼び出し元で .error や .data を扱えるように返す！
  
  }
  catch (err) {
    // 💥 Supabase書き込み中に例外
    return { error: err };
  }
	
}

module.exports = { writeUserDataToSupabase };

