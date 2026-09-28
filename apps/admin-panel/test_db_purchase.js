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
    console.log("1. Fetching Official Frame...");
    const { data: items, error: itemError } = await supabase
      .from("shop_items")
      .select("*")
      .eq("id", "2c925a01-0d4a-4c63-ac10-d5c64a68c88e");
    if (itemError) throw itemError;
    console.log("Official Frame:", items[0]);
    console.log("\n2. Fetching a test user from users table...");
    const { data: users, error: userError } = await supabase
      .from("users")
      .select("id, username, coins")
      .limit(1);
    if (userError) throw userError;
    if (users.length === 0) {
      console.log("No users found in database!");
      return;
    }
    const testUser = users[0];
    console.log("Test User:", testUser);
    console.log(
      `\n3. Simulating insertion into user_inventory for user ${testUser.username} and Official Frame...`,
    );
    const { data: insertData, error: insertError } = await supabase
      .from("user_inventory")
      .insert({
        user_id: testUser.id,
        item_id: "2c925a01-0d4a-4c63-ac10-d5c64a68c88e",
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1e3).toISOString(),
        source: "purchase",
      })
      .select();
    if (insertError) {
      console.error("Insertion failed with error:", insertError);
    } else {
      console.log("Insertion succeeded! Inserted record:", insertData);
      console.log("\n4. Deleting the simulated record to clean up...");
      const { error: deleteError } = await supabase
        .from("user_inventory")
        .delete()
        .eq("user_id", testUser.id)
        .eq("item_id", "2c925a01-0d4a-4c63-ac10-d5c64a68c88e");
      if (deleteError) console.error("Cleanup delete failed:", deleteError);
      else console.log("Cleanup delete succeeded.");
    }
  } catch (err) {
    console.error("Unexpected error:", err);
  }
}

run();
