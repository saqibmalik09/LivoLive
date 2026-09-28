import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { AgencyLevelTable } from "@/components/AgencyLevelTable";
const REWARD_KEYS = ["frame", "bubble", "card_background", "entrance"] as const;
function normalizeShopItem(
  shopItems:
    | {
        id: string;
        name: string;
        image_url: string | null;
      }
    | {
        id: string;
        name: string;
        image_url: string | null;
      }[]
    | null
    | undefined,
) {
  if (!shopItems) return null;
  return Array.isArray(shopItems) ? (shopItems[0] ?? null) : shopItems;
}
function buildRewardsMap(
  assets:
    | Array<{
        feature_key: string;
        shop_item_id?: string | null;
        shop_items?:
          | {
              id: string;
              name: string;
              image_url: string | null;
            }
          | {
              id: string;
              name: string;
              image_url: string | null;
            }[]
          | null;
      }>
    | null
    | undefined,
) {
  const rewards: Record<
    string,
    {
      id: string;
      name: string;
      image_url: string | null;
    } | null
  > = {
    frame: null,
    bubble: null,
    card_background: null,
    entrance: null,
  };
  for (const key of REWARD_KEYS) {
    const asset = assets?.find((a) => a.feature_key === key && a.shop_item_id);
    const shopItem = normalizeShopItem(asset?.shop_items);
    if (shopItem) {
      rewards[key] = {
        id: shopItem.id,
        name: shopItem.name,
        image_url: shopItem.image_url,
      };
    }
  }
  return rewards;
}
export default async function AgencyLevelsPage() {
  const { data: agencyConfigs } = await supabaseAdmin
    .from("agency_level_configs")
    .select("*")
    .order("level", { ascending: true });
  const { data: agencyAssets } = await supabaseAdmin
    .from("agency_level_assets")
    .select("level, feature_key, image_url, shop_item_id, shop_items(id, name, image_url)");
  const levels = (agencyConfigs || []).map((config) => {
    const levelAssets = agencyAssets?.filter((asset) => asset.level === config.level) ?? [];
    return {
      ...config,
      profile_frames: {
        hero_frame: levelAssets.find((a) => a.feature_key === "hero_frame")?.image_url ?? null,
        honor_frame: levelAssets.find((a) => a.feature_key === "honor_frame")?.image_url ?? null,
        charm_frame: levelAssets.find((a) => a.feature_key === "charm_frame")?.image_url ?? null,
      },
      rewards: buildRewardsMap(levelAssets),
    };
  });
  return (
    <div className="space-y-12 pb-32">
      <Link
        href="/settings/levels"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">
          Back to Level Categories
        </span>
      </Link>

      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-300 to-orange-500 tracking-tighter">
          Agency Levels
        </h1>
        <p className="text-white/60 mt-2 font-medium max-w-2xl">
          Configure agency EXP thresholds, tier badges, profile frames (hero / honor / charm), and
          optional shop rewards per level.
        </p>
      </header>

      <AgencyLevelTable initialLevels={levels} />
    </div>
  );
}
