// lib/saveUserInfo.js
import { getUserProfile } from "./lineApiHelpers.js";
import { writeUserDataToSupabase } from "./writeUserDataToSupabase.js";
import { isProd } from "./env.js";

export async function saveUserProfileAndWrite(userId, groupId, ACCESS_TOKEN, inputData = null) {
  const safeGroupId = groupId || "default";
  if (!isProd) {
    console.log("📥 ユーザーデータ保存開始:", { userId, safeGroupId });
  }

  try {
    const profile = await getUserProfile(userId, ACCESS_TOKEN);
    if (!isProd) {
      console.log("📥 取得したプロフィール:", profile);
    }
		
		// プロフィールが取れない場合は書き込まない(ブロックや未followなどがあるため)
		// LINEチャネル設定ミス可能性も有(アクセストークンのスコープにPROFILE権限がない)
		if (!profile) {
			if (isProd) {
				console.log("👤 profileがnull のためスキップ（本番では例外にしない）:", { userId, groupId });
			} else {
				console.warn("⚠️ プロフィール情報の取得に失敗（null）:", { userId, groupId });
			}
			return;
		}
		
    const displayName = profile?.displayName || null;
    const pictureUrl = profile?.pictureUrl || null;
    const statusMessage = profile?.statusMessage || null;
    const shopName = null;

    await writeUserDataToSupabase({
      groupId: safeGroupId,
      userId,
      displayName,
      pictureUrl,
      statusMessage,
      shopName,
      inputData
    });

    if (!isProd) {
      console.log("✅ Supabase にプロフィール情報を書き込み完了");
    }

  } catch (error) {
    console.error("❌ プロフィールの取得または書き込みに失敗:", error);
  }
}
