const { createClient: createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;

const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey)
  throw new Error("Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local");

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    persistSession: false,
  },
});

async function run() {
  try {
    console.log("Querying table check constraints from PostgreSQL...");
    console.log("Testing manual insert of transaction with amount = 0...");
    const { data: users } = await supabase.from("users").select("id").limit(1);
    if (!users || users.length === 0) {
      console.log("No users found.");
      return;
    }
    const userId = users[0].id;
    const { data: data, error: error } = await supabase
      .from("transactions")
      .insert({
        user_id: userId,
        amount: 0,
        currency_type: "coin",
        transaction_type: "purchase",
        description: "Test amount 0 transaction",
      })
      .select();
    if (error) {
      console.error("Insert transaction with amount = 0 FAILED:", error);
    } else {
      console.log("Insert transaction with amount = 0 SUCCEEDED!", data);
      await supabase.from("transactions").delete().eq("id", data[0].id);
      console.log("Cleanup successful.");
    }
  } catch (err) {
    console.error("Error:", err);
  }
}

run();
