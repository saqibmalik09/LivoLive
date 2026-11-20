const NO_EMIT = Object.freeze({ emit: () => false });

function bannersOff() {
  return /^(1|true|on|yes)$/i.test(
    String(process.env.GLOBAL_BANNERS_OFF || "").trim(),
  );
}

function mutedUserIds() {
  return String(process.env.GLOBAL_BANNER_MUTED_USERS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function bannerTarget(io) {
  if (bannersOff()) return NO_EMIT;
  const ids = mutedUserIds();
  return ids.length ? io.except(ids.map((id) => `user:${id}`)) : io;
}

function dbBannerBroadcast() {
  return !bannersOff() && mutedUserIds().length === 0;
}

module.exports = { bannersOff, mutedUserIds, bannerTarget, dbBannerBroadcast };
