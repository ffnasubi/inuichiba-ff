// lib/saveUserInfo.js
const { getUserProfile } = require('./lineApiHelpers.js');
const { writeUserDataToSupabase } = require('./writeUserDataToSupabase.js');

async function saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN, inputData = null) {
  const safeGroupId = groupId || "default";
  
  const { isProd } = require('./env.js'); // env.jsのrequireは関数内で呼び出す直前

  const profile = await getUserProfile(userId, ACCESS_TOKEN);
 	// プロフィールが取れない場合は書き込まない(ブロックや未followなどがあるため)
	// LINEチャネル設定ミス可能性も有(アクセストークンのスコープにPROFILE権限がない)
	if (!profile) {
    // profileがnull のためスキップ（本番では例外にしない）
		if (!isProd) console.warn("⚠️ プロフィール情報の取得に失敗（null）:", { userId, groupId });
		return;
	}
		
  const displayName = profile?.displayName || null;
  const pictureUrl = profile?.pictureUrl || null;
  const statusMessage = profile?.statusMessage || null;
  const shopName = null;

  try {
    const result = await writeUserDataToSupabase({
      groupId: safeGroupId,
      userId,
      displayName,
      pictureUrl,
      statusMessage,
      shopName,
      inputData
    });

    if (!result) {
      if (!isProd) console.warn("⚠️ Supabase書き込み: undefined が返されました");
    } else if (result.error) {
      console.error("❌ Supabase 書き込み失敗:", result.error.message || result.error);
    } else if (result.data?.length > 0) {
      if (!isProd) console.log("✅ Supabase 登録成功:", result.data);
    } else {
      if (!isProd) console.log("🟡 Supabase 書き込みスキップ（既存データ）");
    }
  } catch (err) {
    console.error("💥 Supabase書き込み中に例外:", err);
  }
}

module.exports = { saveUserProfileAndWrite };
