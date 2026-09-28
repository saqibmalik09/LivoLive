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
    console.error("No active staff row for dev");
    process.exit(1);
  }
  console.log("Current staff:", existing);
  let parentId = null;
  const { data: countyAdmins } = await sb
    .from("business_staff")
    .select("id, user_id, staff_code, role")
    .in("role", ["county_admin", "bd_admin"])
    .eq("is_active", true)
    .neq("user_id", user.id)
    .limit(5);
  if (countyAdmins?.length) {
    parentId = countyAdmins[0].id;
    console.log("Parent County Admin:", countyAdmins[0]);
  } else {
    if (existing.parent_staff_id) {
      parentId = existing.parent_staff_id;
      console.log("Keeping existing parent:", parentId);
    } else {
      const { data: supers } = await sb
        .from("business_staff")
        .select("id, staff_code")
        .eq("role", "super_bd")
        .eq("is_active", true)
        .neq("user_id", user.id)
        .limit(1);
      parentId = supers?.[0]?.id || null;
      console.log("Fallback parent Super Admin:", supers?.[0] || null);
    }
  }
  const { data: updated, error: updErr } = await sb
    .from("business_staff")
    .update({
      role: "bd",
      parent_staff_id: parentId,
      updated_at: new Date().toISOString(),
    })
    .eq("id", existing.id)
    .select("id, role, staff_code, parent_staff_id, is_active")
    .single();
  if (updErr) throw updErr;
  console.log("Updated to BD:", updated);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
