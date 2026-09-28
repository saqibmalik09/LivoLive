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
  if (!url || !key) throw new Error("Missing Supabase env");
  const sb = createClient(url, key, {
    auth: {
      persistSession: false,
    },
  });
  const { data: users, error: findErr } = await sb
    .from("users")
    .select("id, username, short_id")
    .ilike("username", "dev")
    .limit(5);
  if (findErr) throw findErr;
  if (!users?.length) {
    const { data: fuzzy } = await sb
      .from("users")
      .select("id, username, short_id")
      .ilike("username", "%dev%")
      .limit(10);
    console.log("No exact username=dev. Matches:", fuzzy);
    process.exit(1);
  }
  const user = users[0];
  console.log("Found user:", {
    id: user.id,
    username: user.username,
    short_id: user.short_id,
  });
  const { data: existing } = await sb
    .from("business_staff")
    .select("id, role, is_active, staff_code")
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();
  if (existing) {
    if (existing.role === "super_bd") {
      console.log("Already active Super BD:", existing);
      return;
    }
    console.log("Deactivating existing staff role:", existing.role);
    await sb
      .from("business_staff")
      .update({
        is_active: false,
        updated_at: new Date().toISOString(),
      })
      .eq("id", existing.id);
  }
  const { data: rpcData, error: rpcErr } = await sb.rpc("create_business_staff", {
    p_target_user_id: user.id,
    p_role: "super_bd",
    p_parent_staff_id: null,
    p_created_by_user_id: null,
  });
  if (rpcErr) {
    console.warn("RPC failed, trying direct insert:", rpcErr.message);
    let staffCode = String(Math.floor(1e5 + Math.random() * 9e5));
    const { data: codeData } = await sb.rpc("generate_staff_code");
    if (codeData) staffCode = String(codeData);
    const { error: insErr } = await sb.from("business_staff").insert({
      user_id: user.id,
      role: "super_bd",
      parent_staff_id: null,
      staff_code: staffCode,
      is_active: true,
    });
    if (insErr) throw insErr;
    console.log("Inserted Super BD via direct insert, code:", staffCode);
    return;
  }
  console.log("create_business_staff result:", rpcData);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
