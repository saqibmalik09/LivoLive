import { ArrowLeft, Zap, Heart, Home, Users, Medal, Building2 } from "lucide-react";
import Link from "next/link";
export default function LevelsLandingPage() {
  const levelTypes = [
    {
      id: "wealth",
      name: "Wealth Levels",
      description: "Levels based on coin spending and gifting.",
      icon: Zap,
      color: "text-amber-400",
      bg: "from-amber-500/20",
    },
    {
      id: "charm",
      name: "Charm Levels",
      description: "Levels based on diamonds/gifts received.",
      icon: Heart,
      color: "text-pink-400",
      bg: "from-pink-500/20",
    },
    {
      id: "agency",
      name: "Agency Levels",
      description: "Agency EXP tiers with hero, honor, and charm profile frames.",
      icon: Building2,
      color: "text-orange-400",
      bg: "from-orange-500/20",
    },
    {
      id: "room",
      name: "Room Levels",
      description: "Progression for chat rooms based on activity.",
      icon: Home,
      color: "text-emerald-400",
      bg: "from-emerald-500/20",
    },
    {
      id: "family",
      name: "Family Levels",
      description: "Levels for families based on member activity.",
      icon: Users,
      color: "text-indigo-400",
      bg: "from-indigo-500/20",
    },
    {
      id: "cp",
      name: "CP Levels",
      description: "Progression for couples based on intimacy.",
      icon: Heart,
      color: "text-red-400",
      bg: "from-red-500/20",
    },
    {
      id: "medals",
      name: "Medal Configuration",
      description: "Set EXP requirements for various achievement medals.",
      icon: Medal,
      color: "text-amber-500",
      bg: "from-amber-600/20",
    },
  ];
  return (
    <div className="space-y-12 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-yellow-400 to-orange-500 tracking-tighter">
          Level Configuration
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Manage EXP milestones and reward unlocking across the platform
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {levelTypes.map((type) => (
          <Link key={type.id} href={`/settings/levels/${type.id}`} className="block h-full">
            <div className="glass-card h-full flex flex-col gap-6 group transition-all relative overflow-hidden hover:border-white/20">
              <div
                className={`absolute top-0 right-0 w-32 h-32 bg-gradient-to-br ${type.bg} to-transparent blur-3xl -mr-16 -mt-16 rounded-full`}
              />

              <div
                className={`p-4 rounded-2xl bg-black/40 border border-white/5 w-fit group-hover:scale-110 transition-transform ${type.color}`}
              >
                <type.icon size={32} strokeWidth={1.5} />
              </div>

              <div className="space-y-2 relative z-10">
                <h3 className="text-xl font-bold tracking-tight">{type.name}</h3>
                <p className="text-sm text-white/40 leading-relaxed">{type.description}</p>
              </div>

              <div className="mt-auto flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-white/20 group-hover:text-white/60 transition-colors">
                Manage Levels <ArrowLeft className="rotate-180" size={12} />
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
