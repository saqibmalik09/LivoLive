'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Building2,
  LayoutDashboard,
  Network,
  ShoppingBag,
  Users,
} from 'lucide-react';
import { cn } from '@/lib/cn';

const navItems = [
  { label: 'Home', icon: LayoutDashboard, href: '/' },
  { label: 'Users', icon: Users, href: '/users' },
  { label: 'Agencies', icon: Building2, href: '/agencies' },
  { label: 'Staff', icon: Network, href: '/staff' },
  { label: 'Shop', icon: ShoppingBag, href: '/shop' },
];

export function Navigation() {
  const pathname = usePathname();

  if (pathname === '/login') return null;

  return (
    <nav className="fixed bottom-8 left-1/2 -translate-x-1/2 w-[90%] max-w-md h-20 glass rounded-[2.5rem] px-6 flex items-center justify-between z-50 border border-white/5">
      {navItems.map((item) => {
        const isActive =
          item.href === '/'
            ? pathname === '/'
            : pathname === item.href || pathname.startsWith(item.href + '/');
        const Icon = item.icon;

        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'nav-item text-white/40 hover:text-white transition-all duration-300',
              isActive && 'active text-purple-400',
            )}
          >
            <div
              className={cn(
                'p-2 rounded-xl transition-colors duration-300',
                isActive ? 'bg-purple-500/10' : 'bg-transparent',
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
