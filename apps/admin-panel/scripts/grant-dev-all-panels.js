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

function nextAgencyCode() {
  return String(Math.floor(1e5 + Math.random() * 9e5));
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
    console.error("No user with username=dev");
    process.exit(1);
  }
  const user = users[0];
  console.log("User:", user);
  const { data: staff } = await sb
    .from("business_staff")
    .select("id, role, staff_code, is_active")
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();
  if (!staff) {
    console.error("No active staff role — run promote-dev-super-bd.js first");
    process.exit(1);
  }
  console.log("Staff:", staff);
  let { data: agency } = await sb
    .from("agencies")
    .select("id, name, agency_code, owner_id, is_active")
    .eq("owner_id", user.id)
    .maybeSingle();
  if (!agency) {
    let agencyCode = nextAgencyCode();
    let created = null;
    for (let i = 0; i < 5; i++) {
      const { data: data, error: error } = await sb
        .from("agencies")
        .insert({
          owner_id: user.id,
          name: "Dev Agency",
          agency_code: agencyCode,
          is_active: true,
          sponsor_staff_id: staff.id,
          approved_by_staff_id: staff.id,
        })
        .select("id, name, agency_code, owner_id, is_active")
        .single();
      if (!error) {
        created = data;
        break;
      }
      if (error.code === "23505" || String(error.message).includes("agency_code")) {
        agencyCode = nextAgencyCode();
        continue;
      }
      throw error;
    }
    if (!created) throw new Error("Failed to create agency");
    agency = created;
    console.log("Created agency:", agency);
  } else {
    if (agency.is_active === false) {
      await sb
        .from("agencies")
        .update({
          is_active: true,
        })
        .eq("id", agency.id);
      agency.is_active = true;
    }
    console.log("Already owns agency:", agency);
  }
  const { data: membership } = await sb
    .from("agency_members")
    .select("id, agency_id")
    .eq("user_id", user.id)
    .eq("agency_id", agency.id)
    .maybeSingle();
  if (!membership) {
    const { error: memErr } = await sb.from("agency_members").insert({
      agency_id: agency.id,
      user_id: user.id,
    });
    if (memErr) throw memErr;
    console.log("Added as host in agency", agency.id);
  } else {
    console.log("Already a host in agency", agency.id);
  }
  console.log("\nDone. Panels available for dev:");
  console.log("  - Super Admin Center (business_staff.role =", staff.role + ")");
  console.log("  - Agency Center (owner of", agency.name + ")");
  console.log("  - Host Center (agency_members)");
  console.log("  - BD Admin / BD: same Staff Center — use preview tiles in app");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
