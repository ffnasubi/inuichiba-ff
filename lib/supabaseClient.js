import { createClient } from '@supabase/supabase-js';
import { supabaseUrl, supabaseKey } from "./env.js";
/// import 'dotenv/config';

console.log("🧪 SUPABASE_URL:", supabaseUrl);
console.log("🧪 supabaseKey（使用中のキー）:", supabaseKey ? "✅ 読み込み成功" : "❌ 読み込み失敗");


export const supabase = createClient(supabaseUrl, supabaseKey);
