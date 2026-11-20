const LUCKY_TOP_BANNER_MIN_MULTIPLIER = 100;
const GAME_TOP_BANNER_DEFAULT_MIN_PAYOUT = 1000000;

function gameTopBannerMinPayout() {
  const raw = String(process.env.BAISHUN_TOP_BANNER_MIN_PAYOUT || "").trim();
  if (raw === "") return GAME_TOP_BANNER_DEFAULT_MIN_PAYOUT;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0
    ? Math.trunc(n)
    : GAME_TOP_BANNER_DEFAULT_MIN_PAYOUT;
}

function isLuckyVariant(variant) {
  return variant === "lucky" || variant === "lucky_pro";
}

function topBannerAllowed(win) {
  const variant = String((win && win.variant) || "");
  if (isLuckyVariant(variant)) {
    return (Number(win.bonus_multiplier) || 0) >= LUCKY_TOP_BANNER_MIN_MULTIPLIER;
  }
  if (variant === "game") {
    return (Number(win.reward_coins) || 0) >= gameTopBannerMinPayout();
  }
  return true;
}

module.exports = {
  LUCKY_TOP_BANNER_MIN_MULTIPLIER: LUCKY_TOP_BANNER_MIN_MULTIPLIER,
  GAME_TOP_BANNER_DEFAULT_MIN_PAYOUT: GAME_TOP_BANNER_DEFAULT_MIN_PAYOUT,
  gameTopBannerMinPayout: gameTopBannerMinPayout,
  topBannerAllowed: topBannerAllowed,
};
