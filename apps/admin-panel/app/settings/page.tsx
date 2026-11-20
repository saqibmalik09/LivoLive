import {
  Crown,
  ShieldCheck,
  ShieldAlert,
  Palette,
  Bell,
  Settings,
  Zap,
  Smartphone,
  Heart,
  Sparkles,
  CalendarDays,
  Gift,
  Smile,
  Building2,
  Coins,
  LayoutPanelLeft,
  Trophy,
  Gamepad2,
  ImageIcon,
  Wallet,
  Banknote,
  Home,
  Network,
  ScrollText,
  Dices,
  CalendarCheck,
  Mic,
  Store,
} from "lucide-react";
import Link from "next/link";
export default function SettingsPage() {
  return (
    <div className="space-y-12 pb-32">
      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 to-orange-400 tracking-tighter">
          Platform Settings
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Configure global system parameters and VIP tiers
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <SettingsCard
          title="Master Panel Access"
          description="Operators, unki Super Admin / BD trees, aur counts — login grant bhi yahan."
          icon={ShieldCheck}
          href="/settings/master-panel"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Maintenance"
          description="Take the whole app down: mobile app shows a blocking screen and the realtime gateway drops every connection."
          icon={ShieldAlert}
          href="/settings/maintenance"
          color="text-amber-300"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Admin Activity Log"
          description="Track Super Admin / platform actions: block, unblock, staff roles, agency requests, balances, and more (Admin panel, Staff web, Mobile app)."
          icon={ScrollText}
          href="/settings/activity-log"
          color="text-amber-300"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Room Mic Emojis"
          description="Mic-seat emoji reactions for live rooms. Free + premium VIP-only items, no coin cost."
          icon={Smile}
          href="/settings/room-emojis"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Lucky Bags"
          description="Room & World coin bag tiers, recipient options, and rules text."
          icon={Gift}
          href="/settings/lucky-bags"
          color="text-pink-400"
          bg="from-pink-500/20"
        />

        <SettingsCard
          title="Lucky & Lucky Pro Gifts"
          description="Receiver %, bonus range, and win chance for Lucky and Lucky Pro category gifts."
          icon={Sparkles}
          href="/settings/lucky-gifts"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Task Check-in Wheel"
          description="Daily task prize wheel: coin min–max ranges and percentage chance per tier (e.g. 100–5000)."
          icon={Dices}
          href="/settings/task-wheel"
          color="text-fuchsia-300"
          bg="from-fuchsia-500/20"
        />

        <SettingsCard
          title="Daily Sign-in"
          description="Day 1–7 launch popup rewards: coins or shop assets. Shown once per day on app open."
          icon={CalendarCheck}
          href="/settings/daily-signin"
          color="text-amber-300"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Voice Backend"
          description="Switch live rooms between Zego (default) and Orbit Voice (LiveKit VM) for testing. Does not remove Zego."
          icon={Network}
          href="/settings/voice-backend"
          color="text-cyan-300"
          bg="from-cyan-500/20"
        />

        <SettingsCard
          title="Game Control"
          description="Enable/disable H5 games, maintenance mode, URLs, bets, timings, multipliers, and engine mode."
          icon={Gamepad2}
          href="/settings/game-control"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Games Logs"
          description="Lazy-loaded bet history: who won/lost how much per game, filters, payout credited, and balance after that bet settled."
          icon={ScrollText}
          href="/settings/game-logs"
          color="text-violet-200"
          bg="from-violet-500/15"
        />

        <SettingsCard
          title="CP Nest Gifts"
          description="Add or edit proposal gifts: name, coin price, and images from Supabase storage."
          icon={Heart}
          href="/cp-nest"
          color="text-pink-400"
          bg="from-pink-500/20"
        />

        <SettingsCard
          title="VIP Level Management"
          description="Edit names, prices, and features for all 6 VIP levels."
          icon={Crown}
          href="/settings/vip"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Wallet Control"
          description="Cash rates, diamond→salary, withdrawal rules, payment methods, merchants & records."
          icon={Wallet}
          href="/settings/wallet"
          color="text-violet-400"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Merchants"
          description="Wholesale tier above coin sellers. Make any ID a merchant, recharge or remove their coins, block them, and see sales, profit and every transaction."
          icon={Store}
          href="/merchants"
          color="text-emerald-400"
          bg="from-emerald-500/20"
        />

        <SettingsCard
          title="Currency Exchange"
          description="Set conversion rates between Diamonds and Beans/Coins."
          icon={Palette}
          href="/settings/exchange"
          color="text-emerald-400"
          bg="from-emerald-500/20"
        />

        <SettingsCard
          title="Cash Withdrawals"
          description="Review and process user cash withdrawal requests (approve / reject / complete)."
          icon={Banknote}
          href="/withdrawals"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Room Decorations"
          description="Catalog backgrounds (free/premium), custom upload coin price, add or remove items."
          icon={Palette}
          href="/settings/room-decorations"
          color="text-indigo-400"
          bg="from-indigo-500/20"
        />

        <SettingsCard
          title="System Configuration"
          description="Global constants like Family creation cost and Game modes."
          icon={Settings}
          href="/settings/general"
          color="text-indigo-400"
          bg="from-indigo-500/20"
        />

        <SettingsCard
          title="Real Name KYC"
          description="Review real-name verification applications, ID media, video auth, and deposits."
          icon={ShieldCheck}
          href="/real-name"
          color="text-sky-300"
          bg="from-sky-500/20"
        />

        <SettingsCard
          title="Security Policies"
          description="Manage banning rules and account verification requirements."
          icon={ShieldCheck}
          href="#"
          color="text-blue-400"
          bg="from-blue-500/20"
          disabled
        />

        <SettingsCard
          title="Level Configuration"
          description="Manage EXP requirements and rewards for User, Wealth, and Room levels."
          icon={Zap}
          href="/settings/levels"
          color="text-yellow-400"
          bg="from-yellow-500/20"
        />

        <SettingsCard
          title="App Version Control"
          description="Landing site URL for Flutter + separate Google Drive APK link for the website download button."
          icon={Smartphone}
          href="/settings/versions"
          color="text-orange-400"
          bg="from-orange-500/20"
        />

        <SettingsCard
          title="Bottom Navigation"
          description="Edit mobile app tab labels and upload bottom nav icons (Home, Party, Message, My)."
          icon={Palette}
          href="/settings/bottom-nav"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Party Screen Background"
          description="Upload top (app bar) and bottom (nav area) images for the Home party screen."
          icon={Palette}
          href="/settings/party-screen"
          color="text-pink-400"
          bg="from-pink-500/20"
        />

        <SettingsCard
          title="Home Banners"
          description="Top Hot-tab carousel — display height, upload, priority, activate/deactivate."
          icon={ImageIcon}
          href="/settings/home-banners"
          color="text-cyan-300"
          bg="from-cyan-500/20"
        />

        <SettingsCard
          title="Mid-Feed Banners"
          description="After first 4 room cards on Hot — exact size 1080×320px (separate from top banners)."
          icon={ImageIcon}
          href="/settings/home-feed-banners"
          color="text-fuchsia-300"
          bg="from-fuchsia-500/20"
        />

        <SettingsCard
          title="Profile Banners"
          description="Me / Profile promo strip — exact size 1080×320px (separate from Home Hot)."
          icon={ImageIcon}
          href="/settings/profile-banners"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Hot Tab Room Top-3"
          description="Retired media cards — Room Daily Top 1–3 now use Room Card Frames."
          icon={Palette}
          href="/settings/hot-cards"
          color="text-orange-400"
          bg="from-orange-500/20"
        />

        <SettingsCard
          title="Ranking Podium Cards"
          description="Room / Agency / Charm / Wealth podium backgrounds on Hot tab."
          icon={Palette}
          href="/settings/ranking-podium"
          color="text-violet-400"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Home Games Row"
          description="Game icons between Ranking Podium and Hot Cards — order and visibility."
          icon={Gamepad2}
          href="/settings/home-games"
          color="text-sky-300"
          bg="from-sky-500/20"
        />

        <SettingsCard
          title="SU Game Hub"
          description="SU / Game tab: categories on the left, which games show in each category."
          icon={Gamepad2}
          href="/settings/su-games"
          color="text-fuchsia-300"
          bg="from-fuchsia-500/20"
        />

        <SettingsCard
          title="Tulasi Games"
          description="Merchant H5: callback URL, synced games, landscape/active, balance activity."
          icon={Gamepad2}
          href="/settings/tulasi-games"
          color="text-cyan-300"
          bg="from-cyan-500/20"
        />

        <SettingsCard
          title="Baishun Games"
          description="Room H5: sync/add Baishun games, upload Coolify icons, activate for room sheet."
          icon={Dices}
          href="/settings/baishun-games"
          color="text-orange-300"
          bg="from-orange-500/20"
        />

        <SettingsCard
          title="Room Card Frames"
          description="Daily TOP 1–3 frames on Hot Room Top-3 cards and Popular/New grid."
          icon={Palette}
          href="/settings/room-card-frames"
          color="text-emerald-400"
          bg="from-emerald-500/20"
        />

        <SettingsCard
          title="Home Podium Frames"
          description="TOP 1/2/3 frames + optional Room/Agency/Charm/Wealth overrides on home podium."
          icon={Palette}
          href="/settings/ranking-assets"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Agency Ranking Assets"
          description="Daily / weekly / monthly TOP 1–3 frames and badges for Gift Center Agency tab."
          icon={Building2}
          href="/settings/ranking-assets/agency"
          color="text-orange-400"
          bg="from-orange-500/20"
        />

        <SettingsCard
          title="Rupee Game / Lucky Offer"
          description="Coin-entry lucky draw campaigns, prizes, winner draw, refunds, and help content."
          icon={Coins}
          href="/settings/rupee-game"
          color="text-emerald-400"
          bg="from-emerald-500/20"
        />

        <SettingsCard
          title="Party Events"
          description="Event cards on Home → Events tab: banners, dates, and tap actions (rankings, games)."
          icon={CalendarDays}
          href="/settings/party-events"
          color="text-sky-400"
          bg="from-sky-500/20"
        />

        <SettingsCard
          title="Room Float Icons"
          description="Square cycling game + event icons on the live room right-bottom rail."
          icon={LayoutPanelLeft}
          href="/settings/room-float"
          color="text-amber-400"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Room Reward Gift Box"
          description="Lv1–Lv5 points, reward pools, and rules for the room gift-box float button."
          icon={Gift}
          href="/settings/room-rewards"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="BD / Agency Policy"
          description="Host gift 30%, Agency LV1–25 charm salaries, BD LV1–10 targets, and settlement runs."
          icon={Network}
          href="/settings/bd-center"
          color="text-violet-300"
          bg="from-violet-500/20"
        />

        <SettingsCard
          title="Coin Seller Policy"
          description="USD seller tiers, coin ratios, VIP/frame rewards, and fulfill reseller stock packages."
          icon={Coins}
          href="/settings/coin-seller-policy"
          color="text-amber-300"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Room Banners"
          description="Search any host room and change its card banner or live background image."
          icon={Home}
          href="/settings/rooms"
          color="text-sky-300"
          bg="from-sky-500/20"
        />

        <SettingsCard
          title="Room Reward"
          description="Weekly owner rewards: room targets with coins or shop assets — My Profile page + room float."
          icon={Trophy}
          href="/settings/weekly-room-rewards"
          color="text-amber-300"
          bg="from-amber-500/20"
        />

        <SettingsCard
          title="Mic Daily Rewards"
          description="Daily mic-on duration tiers (30m / 1h…): coins or assets for unmuted seated users."
          icon={Mic}
          href="/settings/mic-daily-rewards"
          color="text-sky-300"
          bg="from-sky-500/20"
        />

        <SettingsCard
          title="Branding & Assets"
          description="Update default banners, icons, and theme colors."
          icon={Palette}
          href="#"
          color="text-pink-400"
          bg="from-pink-500/20"
          disabled
        />
      </div>
    </div>
  );
}
function SettingsCard({ title, description, icon: Icon, href, color, bg, disabled = false }: any) {
  const CardContent = (
    <div
      className={`glass-card h-full flex flex-col gap-6 group transition-all relative overflow-hidden ${disabled ? "opacity-50 grayscale" : "hover:border-white/20"}`}
    >
      <div
        className={`absolute top-0 right-0 w-32 h-32 bg-gradient-to-br ${bg} to-transparent blur-3xl -mr-16 -mt-16 rounded-full`}
      />

      <div
        className={`p-4 rounded-2xl bg-black/40 border border-white/5 w-fit group-hover:scale-110 transition-transform ${color}`}
      >
        <Icon size={32} strokeWidth={1.5} />
      </div>

      <div className="space-y-2 relative z-10">
        <h3 className="text-xl font-bold tracking-tight">{title}</h3>
        <p className="text-sm text-white/40 leading-relaxed">{description}</p>
      </div>

      {!disabled && (
        <div className="mt-auto flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-white/20 group-hover:text-white/60 transition-colors">
          Configure Now <Settings size={12} />
        </div>
      )}
      {disabled && (
        <div className="mt-auto text-[10px] font-black uppercase tracking-widest text-white/10">
          Coming Soon
        </div>
      )}
    </div>
  );
  if (disabled) return CardContent;
  return (
    <Link href={href} className="block h-full">
      {CardContent}
    </Link>
  );
}
