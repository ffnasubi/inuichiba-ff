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
  try {
    const timestamp = getFormattedJST();
    const safeGroupId = groupId || "default";

    let supabaseHolder = {};              // ← client を格納するオブジェクトを定義
    initSupabaseClient(supabaseHolder);   // ← client を初期化(lient を格納（参照渡し）)
    const supabase = supabaseHolder.client;
    const usersTable = supabaseHolder.usersTable;

    // ✅ isProd は Secrets 反映後に require する
    const { isProd } = require('./env.js');

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

    if (!isProd) {
			console.log("🕐 書き込み開始:", timestamp);
      console.log("📦 書き込みデータ:", userData);
    }

    const { data, error } = await supabase
      .from(usersTable)
      .upsert([userData], {
        onConflict: ['groupId', 'userId']
      });

    if (error) {
      console.error("❌ Supabase書き込みエラー:", error);
    }

    if (data && !isProd) {
      console.log("✅ Supabaseに保存されました:", data);
    }
		// ✅ 本番でも出す：Supabaseの応答を受けた時点の正確なJS時刻（ISO形式）
		console.log("⏱ 書き込み完了タイムスタンプ:", getFormattedJST());

  } catch (err) {
    console.error("💥 例外でクラッシュしました:", err);
  }
	
}

module.exports = writeUserDataToSupabase;

