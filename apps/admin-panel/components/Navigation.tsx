"use client";
import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  MessageSquare,
  Settings,
  ShoppingBag,
  ClipboardList,
  Heart,
} from "lucide-react";
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
const navItems = [
  { label: "Users", icon: Users, href: "/users" },
  { label: "Shop", icon: ShoppingBag, href: "/shop" },
  { label: "Home", icon: LayoutDashboard, href: "/" },
  { label: "CP", icon: Heart, href: "/cp-nest" },
  { label: "Set", icon: Settings, href: "/settings" },
];
export function Navigation() {
  const pathname = usePathname();
  return (
    <nav className="fixed bottom-8 left-1/2 -translate-x-1/2 w-[90%] max-w-md h-20 glass rounded-[2.5rem] px-10 flex items-center justify-between z-50 border border-white/5">
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
              "nav-item text-white/40 hover:text-white transition-all duration-300",
              isActive && "active text-purple-400",
            )}
          >
            <div
              className={cn(
                "p-2 rounded-xl transition-colors duration-300",
                isActive ? "bg-purple-500/10" : "bg-transparent",
              )}
            >
              <Icon size={22} strokeWidth={isActive ? 2.5 : 1.5} />
            </div>
            <span className="text-[9px] font-bold uppercase tracking-[0.15em] mt-1">
              {item.label}
            </span>
          </Link>
        );
      })}
    </nav>
  );
}
