const { createClient } = require('@supabase/supabase-js');

// 遅延実行（安全な初期化）
function initSupabaseClient(clientOut) {
    // env.jsのrequireは関数内呼び出しで遅く(使う直前に)呼び出す(初期化エラー防止)
    const { supabaseUrl, supabaseKey, usersTable } = require('./env.js');
    if (!supabaseUrl) {
      throw new Error("❌ supabaseUrl is undefined(from initSupabaseClient).");
    }
    if (!supabaseKey) {
      throw new Error("❌ supabaseKey is undefined(from initSupabaseClient).");
    }
  
    clientOut.client = createClient(supabaseUrl, supabaseKey);
    clientOut.usersTable = usersTable;
  }
  
  module.exports = initSupabaseClient;


