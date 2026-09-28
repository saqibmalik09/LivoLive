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

const ITEM_ID = "2c925a01-0d4a-4c63-ac10-d5c64a68c88e";

async function run() {
  try {
    console.log("Fetching test user...");
    const { data: users, error: userError } = await supabase
      .from("users")
      .select("id, username, coins, wealth_value, wealth_level")
      .limit(1);
    if (userError) throw userError;
    const user = users[0];
    console.log("Test User:", user);
    console.log("\nStep 1: Fetching item info...");
    const { data: items, error: itemError } = await supabase
      .from("shop_items")
      .select("price_coins, duration_days, is_active")
      .eq("id", ITEM_ID)
      .eq("is_active", true);
    if (itemError) throw itemError;
    if (items.length === 0) {
      console.log("Item not found or inactive");
      return;
    }
    const item = items[0];
    const v_item_price = item.price_coins;
    const v_duration = item.duration_days;
    console.log(`Item Price: ${v_item_price}, Duration Days: ${v_duration}`);
    const v_balance = user.coins;
    console.log(`Step 2: Checking balance (User Coins: ${v_balance} vs Price: ${v_item_price})`);
    if (v_balance < v_item_price) {
      console.log("Error: Insufficient coins");
      return;
    }
    const v_new_wealth_value = (user.wealth_value || 0) + v_item_price;
    console.log(
      `Step 3: New wealth value calculation: ${user.wealth_value} + ${v_item_price} = ${v_new_wealth_value}`,
    );
    console.log("Step 4: Fetching new wealth level from level_configs...");
    const { data: levelConfigs, error: levelError } = await supabase
      .from("level_configs")
      .select("level")
      .eq("category", "wealth")
      .lte("min_exp", v_new_wealth_value)
      .order("level", {
        ascending: false,
      })
      .limit(1);
    if (levelError) throw levelError;
    let v_new_wealth_level = levelConfigs.length > 0 ? levelConfigs[0].level : 1;
    console.log(`New wealth level: ${v_new_wealth_level}`);
    console.log(
      `Step 5: Updating user ${user.username} (setting coins=${user.coins - v_item_price}, wealth_value=${v_new_wealth_value}, wealth_level=${v_new_wealth_level})...`,
    );
    const { data: updateData, error: updateError } = await supabase
      .from("users")
      .update({
        coins: user.coins - v_item_price,
        wealth_value: v_new_wealth_value,
        wealth_level: v_new_wealth_level,
      })
      .eq("id", user.id)
      .select();
    if (updateError) {
      console.error("Update User failed:", updateError);
      return;
    }
    console.log("Update User succeeded:", updateData[0]);
    console.log("Step 6: Adding to user_inventory...");
    const expiresAt = new Date(Date.now() + v_duration * 24 * 60 * 60 * 1e3).toISOString();
    const { data: invData, error: invError } = await supabase
      .from("user_inventory")
      .insert({
        user_id: user.id,
        item_id: ITEM_ID,
        expires_at: expiresAt,
        source: "purchase",
      })
      .select();
    if (invError) {
      console.error("Inventory Insertion failed:", invError);
      console.log("Rolling back user updates...");
      await supabase
        .from("users")
        .update({
          coins: user.coins,
          wealth_value: user.wealth_value,
          wealth_level: user.wealth_level,
        })
        .eq("id", user.id);
      return;
    }
    console.log("Inventory Insertion succeeded:", invData[0]);
    console.log("Step 7: Inserting into transactions...");
    const { data: txData, error: txError } = await supabase
      .from("transactions")
      .insert({
        user_id: user.id,
        amount: -v_item_price,
        currency_type: "coin",
        transaction_type: "purchase",
        reference_id: ITEM_ID,
      })
      .select();
    if (txError) {
      console.error("Transaction Insertion failed:", txError);
      console.log("Rolling back inventory & user updates...");
      await supabase.from("user_inventory").delete().eq("user_id", user.id).eq("item_id", ITEM_ID);
      await supabase
        .from("users")
        .update({
          coins: user.coins,
          wealth_value: user.wealth_value,
          wealth_level: user.wealth_level,
        })
        .eq("id", user.id);
      return;
    }
    console.log("Transaction Insertion succeeded:", txData[0]);
    console.log("\nSimulation completed successfully! Cleaning up generated records...");
    await supabase.from("user_inventory").delete().eq("user_id", user.id).eq("item_id", ITEM_ID);
    await supabase.from("transactions").delete().eq("id", txData[0].id);
    await supabase
      .from("users")
      .update({
        coins: user.coins,
        wealth_value: user.wealth_value,
        wealth_level: user.wealth_level,
      })
      .eq("id", user.id);
    console.log("Cleanup completed successfully.");
  } catch (err) {
    console.error("Unexpected error during simulation:", err);
  }
}

run();
