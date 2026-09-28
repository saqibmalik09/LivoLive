const { createClient: createClient } = require("@supabase/supabase-js");

const fs = require("fs");

const path = require("path");

function loadEnv() {
  const p = path.join(__dirname, "..", ".env.local");
  const env = fs.readFileSync(p, "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return {
    url: get("NEXT_PUBLIC_SUPABASE_URL"),
    key: get("SUPABASE_SERVICE_ROLE_KEY"),
  };
}

async function main() {
  const { url: url, key: key } = loadEnv();
  const sb = createClient(url, key, {
    auth: {
      persistSession: false,
    },
  });
  const { data: user } = await sb
    .from("users")
    .select("id, username, short_id")
    .ilike("username", "dev")
    .maybeSingle();
  console.log("user", user);
  const { data: staff } = await sb
    .from("business_staff")
    .select("id, role, staff_code, is_active, user_id")
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();
  console.log("staff", staff);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
