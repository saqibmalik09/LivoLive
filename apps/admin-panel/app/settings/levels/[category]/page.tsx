import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { LevelTable } from "@/components/LevelTable";
import { MedalTable } from "@/components/MedalTable";
interface LevelCategoryPageProps {
  params: Promise<{
    category: string;
  }>;
}
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
export default async function LevelCategoryPage({ params }: LevelCategoryPageProps) {
  const { category } = await params;
  let table = "";
  let levels: any[] = [];
  let medals: any[] = [];
  const validCategories = ["user", "wealth", "charm", "room", "family", "cp", "medals"];
  if (!validCategories.includes(category)) {
    notFound();
  }
  if (category === "medals") {
    const { data } = await supabaseAdmin
      .from("shop_items")
      .select("*")
      .eq("source_type", "medal")
      .eq("is_active", true)
      .order("required_wealth_value", { ascending: true });
    medals = data || [];
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
          <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 to-orange-500 tracking-tighter capitalize">
            Medal Configuration
          </h1>
          <p className="text-white/60 mt-2 font-medium">
            Set exactly which EXP threshold awards each achievement badge
          </p>
        </header>

        <MedalTable initialMedals={medals} />
      </div>
    );
  }
  switch (category) {
    case "user":
      table = "level_configs";
      const { data: userLevelData } = await supabaseAdmin
        .from(table)
        .select("*")
        .eq("category", "user_level")
        .order("level", { ascending: true });
      levels = userLevelData || [];
      break;
    case "wealth":
      table = "level_configs";
      const { data: wealthLevelData } = await supabaseAdmin
        .from(table)
        .select("*")
        .eq("category", "user_wealth")
        .order("level", { ascending: true });
      const { data: wealthAssets } = await supabaseAdmin
        .from("wealth_level_assets")
        .select("level, feature_key, shop_item_id, shop_items(id, name, image_url)");
      levels = (wealthLevelData || []).map((config) => ({
        ...config,
        rewards: buildRewardsMap(wealthAssets?.filter((asset) => asset.level === config.level)),
      }));
      break;
    case "charm":
      table = "charm_level_configs";
      const { data: charmConfigs } = await supabaseAdmin
        .from(table)
        .select("*")
        .order("level", { ascending: true });
      const { data: charmAssets } = await supabaseAdmin
        .from("charm_level_assets")
        .select("level, feature_key, image_url, shop_item_id, shop_items(id, name, image_url)");
      levels = (charmConfigs || []).map((config) => {
        const levelAssets = charmAssets?.filter((asset) => asset.level === config.level) ?? [];
        const badgeAsset = levelAssets.find((asset) => asset.feature_key === "badge");
        return {
          ...config,
          badge_url: badgeAsset?.image_url || "",
          rewards: buildRewardsMap(levelAssets),
        };
      });
      break;
    case "room":
      table = "room_level_configs";
      const { data: rlcData } = await supabaseAdmin
        .from(table)
        .select("*")
        .order("level", { ascending: true });
      levels = rlcData || [];
      break;
    case "family":
      table = "family_level_configs";
      const { data: flcData } = await supabaseAdmin
        .from(table)
        .select("*")
        .order("level", { ascending: true });
      levels = flcData || [];
      break;
    case "cp":
      table = "cp_level_configs";
      const { data: cplcData } = await supabaseAdmin
        .from(table)
        .select("*")
        .order("level", { ascending: true });
      levels = cplcData || [];
      break;
  }
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
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-white to-white/40 tracking-tighter capitalize">
          {category} Levels
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Configure experience thresholds and rewards for {category} progression
        </p>
      </header>

      <LevelTable category={category} initialLevels={levels} />
    </div>
  );
}
