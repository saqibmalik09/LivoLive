const { createClient: createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;

const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey)
  throw new Error("Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local");

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function run() {
  const { data: data, error: error } = await supabase.from("users").select("*").limit(1);
  if (error) {
    console.error("Error fetching users:", error);
  } else {
    console.log("User columns:", Object.keys(data[0] || {}));
    console.log("Sample user:", data[0]);
  }
}

run();
