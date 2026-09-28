'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Network,
  Building2,
  ClipboardList,
  UserPlus,
  Crown,
  LogOut,
  Menu,
  X,
  ShieldBan,
  ScrollText,
  GitBranch,
} from 'lucide-react';
import { useState } from 'react';
import { cn } from '@/lib/utils';
import { signOut } from '@/lib/actions';
import type { PortalRole } from '@/lib/permissions';
import { getPortalPermissions } from '@/lib/permissions';

type NavProps = {
  username: string;
  staffCode: string;
  role: PortalRole;
  onNavigate?: () => void;
};

function useNavItems(role: PortalRole) {
  const permissions = getPortalPermissions(role);
  const items = [
    { href: '/', label: 'Dashboard', icon: LayoutDashboard },
    { href: '/network', label: 'Network', icon: GitBranch },
    { href: '/team', label: 'Team', icon: Network },
    { href: '/agencies', label: 'Agencies', icon: Building2 },
  ];

  if (permissions.canBanUnban) {
    items.push({ href: '/moderation', label: 'Ban / Unban', icon: ShieldBan });
  }

  if (permissions.canCreateStaff && permissions.createStaffLabel) {
    items.push({
      href: '/create-staff',
      label: permissions.createStaffLabel,
      icon: UserPlus,
    });
  }

  items.push({ href: '/applications', label: 'Requests', icon: ClipboardList });
  items.push({ href: '/activity', label: 'Activity', icon: ScrollText });
  items.push({ href: '/my-agency', label: 'My Agency', icon: Crown });
  return items;
}

function NavLinks({ role, onNavigate }: Pick<NavProps, 'role' | 'onNavigate'>) {
  const pathname = usePathname();
  const navItems = useNavItems(role);

  return (
    <nav className="flex flex-col gap-1">
      {navItems.map(({ href, label, icon: Icon }) => {
        const active =
          pathname === href ||
          (href !== '/' && pathname.startsWith(href)) ||
          (href === '/create-staff' && pathname.startsWith('/create-bd-admin'));
        return (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            className={cn(
              'flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition',
              active
                ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                : 'text-white/60 hover:bg-white/5 hover:text-white'
            )}
          >
            <Icon size={18} />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

export function Sidebar({ username, staffCode, role }: NavProps) {
  const permissions = getPortalPermissions(role);

  return (
    <aside className="hidden lg:flex lg:flex-col lg:w-64 lg:fixed lg:inset-y-0 border-r border-white/10 bg-black/40 backdrop-blur-xl p-6">
      <div className="mb-8">
        <p className="text-[10px] font-black uppercase tracking-[0.2em] text-amber-400/80">SK LIVE</p>
        <h1 className="text-xl font-black italic mt-1">Super Admin</h1>
        <p className="text-[10px] font-bold uppercase tracking-wider text-purple-300/70 mt-2">
          {permissions.label}
        </p>
        <p className="text-xs text-white/40 mt-2 truncate">{username}</p>
        <p className="text-[10px] text-white/30 font-mono">{staffCode}</p>
      </div>
      <NavLinks role={role} />
      <form action={signOut} className="mt-auto pt-6">
        <button type="submit" className="btn-ghost w-full text-sm">
          <LogOut size={16} />
          Sign out
        </button>
      </form>
    </aside>
  );
}

export function MobileHeader({ username, role }: { username: string; role: PortalRole }) {
  const [open, setOpen] = useState(false);
  const permissions = getPortalPermissions(role);

  return (
    <>
      <header className="lg:hidden sticky top-0 z-40 flex items-center justify-between border-b border-white/10 bg-black/70 backdrop-blur-xl px-4 py-3">
        <div>
          <p className="text-xs font-black text-amber-400">Super Admin · {permissions.label}</p>
          <p className="text-sm font-semibold truncate max-w-[200px]">{username}</p>
        </div>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="p-2 rounded-lg bg-white/5"
          aria-label="Open menu"
        >
          <Menu size={22} />
        </button>
      </header>

      {open && (
        <div className="lg:hidden fixed inset-0 z-50">
          <button
            type="button"
            className="absolute inset-0 bg-black/60"
            onClick={() => setOpen(false)}
            aria-label="Close menu"
          />
          <div className="absolute right-0 top-0 h-full w-[min(100%,280px)] bg-[#0a0a0f] border-l border-white/10 p-6 flex flex-col">
            <div className="flex justify-between items-center mb-6">
              <span className="font-black">Menu</span>
              <button type="button" onClick={() => setOpen(false)} className="p-2">
                <X size={20} />
              </button>
            </div>
            <NavLinks role={role} onNavigate={() => setOpen(false)} />
            <form action={signOut} className="mt-auto pt-6">
              <button type="submit" className="btn-ghost w-full text-sm">
                <LogOut size={16} />
                Sign out
              </button>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

export function MobileBottomNav({ role }: { role: PortalRole }) {
  const pathname = usePathname();
  const permissions = getPortalPermissions(role);
  const items = [
    { href: '/', label: 'Home', icon: LayoutDashboard },
    { href: '/network', label: 'Network', icon: GitBranch },
    { href: '/team', label: 'Team', icon: Network },
    { href: '/agencies', label: 'Agencies', icon: Building2 },
  ];

  return (
    <nav className="lg:hidden fixed bottom-0 inset-x-0 z-40 border-t border-white/10 bg-black/80 backdrop-blur-xl px-2 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))]">
      <div className="flex justify-around">
        {items.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || (href !== '/' && pathname.startsWith(href));
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                'flex flex-col items-center gap-1 px-3 py-1 text-[10px] font-bold',
                active ? 'text-amber-400' : 'text-white/40'
              )}
              aria-label={label}
            >
              <Icon size={20} />
              {label}
            </Link>
          );
        })}
      </div>
      <p className="sr-only">{permissions.label}</p>
    </nav>
  );
}
