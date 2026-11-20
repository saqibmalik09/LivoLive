"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, Send, Users, ScrollText, Banknote } from "lucide-react";
import { cn } from "@/lib/cn";

const navItems = [
  { label: "Home", icon: LayoutDashboard, href: "/" },
  { label: "Recharge", icon: Send, href: "/recharge" },
  { label: "Sellers", icon: Users, href: "/sellers" },
  { label: "History", icon: ScrollText, href: "/history" },
  { label: "Payout", icon: Banknote, href: "/withdrawals" },
];

export function Navigation() {
  const pathname = usePathname();
  return (
    <nav className="fixed bottom-6 left-1/2 -translate-x-1/2 w-[94%] max-w-md h-20 glass rounded-[2.5rem] px-5 flex items-center justify-between z-50 border border-white/5">
      {navItems.map((item) => {
        const isActive =
          item.href === "/"
            ? pathname === "/"
            : pathname === item.href || pathname.startsWith(item.href + "/");
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex flex-col items-center text-white/40 hover:text-white transition-all duration-300",
              isActive && "text-emerald-400",
            )}
          >
            <div
              className={cn(
                "p-2 rounded-xl transition-colors duration-300",
                isActive ? "bg-emerald-500/10" : "bg-transparent",
              )}
            >
              <Icon size={21} strokeWidth={isActive ? 2.5 : 1.5} />
            </div>
            <span className="text-[9px] font-bold uppercase tracking-[0.15em] mt-0.5">
              {item.label}
            </span>
          </Link>
        );
      })}
    </nav>
  );
}
