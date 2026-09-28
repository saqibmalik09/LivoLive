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
    .limit(1);
  if (findErr) throw findErr;
  if (!users?.length) {
    console.error("No username=dev");
    process.exit(1);
  }
  const user = users[0];
  console.log("User:", user);
  const { data: existing } = await sb
    .from("business_staff")
    .select("id, role, is_active, staff_code, parent_staff_id")
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();
  if (!existing) {
    console.error("No active staff row — creating Super Admin");
    let staffCode = String(Math.floor(1e5 + Math.random() * 9e5));
    const { data: codeData } = await sb.rpc("generate_staff_code");
    if (codeData) staffCode = String(codeData);
    const { data: inserted, error: insErr } = await sb
      .from("business_staff")
      .insert({
        user_id: user.id,
        role: "super_bd",
        parent_staff_id: null,
        staff_code: staffCode,
        is_active: true,
      })
      .select("id, role, staff_code, parent_staff_id, is_active")
      .single();
    if (insErr) throw insErr;
    console.log("Created Super Admin:", inserted);
    return;
  }
  console.log("Current staff:", existing);
  if (existing.role === "super_bd") {
    console.log("Already Super Admin");
    return;
  }
  const { data: updated, error: updErr } = await sb
    .from("business_staff")
    .update({
      role: "super_bd",
      parent_staff_id: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", existing.id)
    .select("id, role, staff_code, parent_staff_id, is_active")
    .single();
  if (updErr) throw updErr;
  console.log("Updated to Super Admin:", updated);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
