const { createClient: createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;

const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey)
  throw new Error("Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local");

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function run() {
  try {
    console.log('Searching for user "Ali"...');
    const { data: users, error: userError } = await supabase
      .from("users")
      .select("id, username, diamonds, charm_value")
      .ilike("username", "%ali%");
    if (userError) throw userError;
    console.log('Found users matching "Ali":', users);
    console.log('\nSearching for room "Mohsins Royal Lounge"...');
    const { data: rooms, error: roomError } = await supabase
      .from("rooms")
      .select("id, title, host_id")
      .ilike("title", "%mohsin%");
    if (roomError) throw roomError;
    console.log('Found rooms matching "Mohsin":', rooms);
    if (users.length === 0 || rooms.length === 0) {
      console.log("User or Room not found. Cannot proceed.");
      return;
    }
    const aliUser = users.find((u) => u.username.toLowerCase() === "ali") || users[0];
    const room = rooms[0];
    console.log(
      `\nAnalyzing gifts sent to User: ${aliUser.username} (${aliUser.id}) in Room: ${room.title} (${room.id})`,
    );
    const { data: giftLogs, error: giftLogsError } = await supabase
      .from("gift_logs")
      .select(
        `\n        id,\n        sender_id,\n        receiver_id,\n        gift_id,\n        amount,\n        created_at,\n        sender:sender_id(username),\n        receiver:receiver_id(username),\n        gift:gift_id(name)\n      `,
      )
      .eq("room_id", room.id)
      .order("created_at", {
        ascending: false,
      });
    if (giftLogsError) throw giftLogsError;
    console.log(`Total gift logs found in this room: ${giftLogs.length}`);
    const aliGifts = giftLogs.filter((g) => g.receiver_id === aliUser.id);
    console.log(`\n--- Gifts received by ${aliUser.username} in this room ---`);
    for (const g of aliGifts) {
      const { data: earnings, error: earningsError } = await supabase
        .from("earning_logs")
        .select("*")
        .eq("gift_log_id", g.id);
      console.log(
        `Gift: ${g.gift?.name || "Unknown"} | Value: ${g.amount} coins | Sent by: ${g.sender?.username || "Unknown"} | Date: ${g.created_at}`,
      );
      if (earnings && earnings.length > 0) {
        console.log(`   -> Diamonds received by host: ${earnings[0].host_amount}`);
        console.log(`   -> Diamonds received by agency: ${earnings[0].agency_amount}`);
        console.log(`   -> Amount received by admin: ${earnings[0].admin_amount}`);
      } else {
        console.log(`   -> No detailed earning log found (likely direct conversion)`);
      }
    }
    const othersGiftsMap = {};
    giftLogs.forEach((g) => {
      if (g.receiver_id !== aliUser.id) {
        const name = g.receiver?.username || g.receiver_id;
        othersGiftsMap[name] = othersGiftsMap[name] || {
          totalCoins: 0,
          count: 0,
        };
        othersGiftsMap[name].totalCoins += g.amount;
        othersGiftsMap[name].count += 1;
      }
    });
    console.log("\n--- Total gifts received by other users in this room ---");
    if (Object.keys(othersGiftsMap).length === 0) {
      console.log("No other users received gifts in this room.");
    } else {
      for (const [name, stats] of Object.entries(othersGiftsMap)) {
        console.log(
          `User: ${name} | Total Gift Value received: ${stats.totalCoins} coins (${stats.count} gifts)`,
        );
      }
    }
  } catch (err) {
    console.error("Error:", err);
  }
}

run();
