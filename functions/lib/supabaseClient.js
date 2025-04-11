const { createClient } = require('@supabase/supabase-js');
const { supabaseUrl, supabaseKey } = require('./env.js');

console.log("🧪 supabaseKey（使用中のキー）:", supabaseKey ? "✅ 読み込み成功" : "❌ 読み込み失敗");


export const supabase = createClient(supabaseUrl, supabaseKey);
