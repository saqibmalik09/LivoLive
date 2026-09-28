'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { AgencyNode, HostNode, StaffNode } from '@/lib/types';
import { ChevronDown, ChevronRight, Building2, User, Users } from 'lucide-react';
import { cn } from '@/lib/utils';

const roleLabels: Record<string, string> = {
  super_bd: 'Super Admin',
  county_admin: 'Country Admin',
  bd_admin: 'Country Admin',
  bd: 'BD',
  assistant: 'Assistant',
  customer_service: 'Customer Service',
};

type Props = {
  staff: StaffNode[];
  agencies: AgencyNode[];
  hosts: HostNode[];
  rootStaffId: string;
  compact?: boolean;
};

export function HierarchyTree({ staff, agencies, hosts, rootStaffId, compact }: Props) {
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const root = staff.find((s) => s.id === rootStaffId);
  const childrenOf = (parentId: string) => staff.filter((s) => s.parent_staff_id === parentId);

  function toggle(id: string) {
    setExpanded((e) => ({ ...e, [id]: !e[id] }));
  }

  function renderStaffNode(node: StaffNode, depth: number) {
    const kids = childrenOf(node.id);
    const nodeAgencies = agencies.filter((a) => a.sponsor_staff_id === node.id);
    const hasChildren = kids.length > 0 || nodeAgencies.length > 0;
    const isOpen = expanded[node.id] ?? depth < 1;

    return (
      <div key={node.id} className="select-none">
        <div
          className={cn(
            'flex items-center gap-2 rounded-lg py-2 px-2 hover:bg-white/5',
            compact && 'text-sm'
          )}
          style={{ paddingLeft: `${depth * 16 + 8}px` }}
        >
          {hasChildren ? (
            <button type="button" onClick={() => toggle(node.id)} className="text-white/40">
              {isOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            </button>
          ) : (
            <span className="w-4" />
          )}
          <Users size={14} className="text-amber-400/80 shrink-0" />
          <div className="min-w-0 flex-1">
            <Link href={`/team/${node.id}`} className="font-semibold hover:text-amber-300 truncate block">
              {node.username}
            </Link>
            <p className="text-[10px] text-white/40">
              {roleLabels[node.role] || node.role} · {node.staff_code} · ID {node.short_id}
            </p>
          </div>
        </div>

        {isOpen && (
          <>
            {kids.map((child) => renderStaffNode(child, depth + 1))}
            {nodeAgencies.map((agency) => {
              const agencyHosts = hosts.filter((h) => h.agency_id === agency.id);
              const agencyKey = `agency-${agency.id}`;
              const agencyOpen = expanded[agencyKey] ?? false;
              return (
                <div key={agency.id} style={{ paddingLeft: `${(depth + 1) * 16 + 8}px` }}>
                  <div className="flex items-center gap-2 rounded-lg py-2 px-2 hover:bg-white/5">
                    {agencyHosts.length > 0 ? (
                      <button type="button" onClick={() => toggle(agencyKey)} className="text-white/40">
                        {agencyOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    ) : (
                      <span className="w-4" />
                    )}
                    <Building2 size={14} className="text-emerald-400/80 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <Link href={`/agencies/${agency.id}`} className="font-semibold hover:text-emerald-300 truncate block">
                        {agency.name}
                      </Link>
                      <p className="text-[10px] text-white/40">
                        Agency · {agency.agency_code} · {agency.host_count} hosts
                      </p>
                    </div>
                  </div>
                  {agencyOpen &&
                    agencyHosts.map((host) => (
                      <div
                        key={host.member_id}
                        className="flex items-center gap-2 py-1.5 px-2 text-sm text-white/70"
                        style={{ paddingLeft: `${(depth + 2) * 16 + 8}px` }}
                      >
                        <User size={12} className="text-blue-300/80" />
                        <span className="truncate">{host.username}</span>
                        <span className="text-[10px] text-white/30">ID {host.short_id}</span>
                      </div>
                    ))}
                </div>
              );
            })}
          </>
        )}
      </div>
    );
  }

  if (!root) {
    return <p className="text-white/40 text-sm">No hierarchy data.</p>;
  }

  return <div className="space-y-1">{renderStaffNode(root, 0)}</div>;
}
