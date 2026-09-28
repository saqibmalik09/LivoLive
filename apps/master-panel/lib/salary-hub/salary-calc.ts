import 'server-only';

import { supabaseAdmin } from '@/lib/supabase';
import { formatUsd, periodToBdMonth } from '@/lib/salary-hub/constants';

export { formatUsd, periodToBdMonth };

export type SalaryTierRow = {
  id: string;
  tier_name: string | null;
  diamonds_target: number;
  hours_target: number;
  days_target: number;
  reward_amount: number;
  is_active: boolean | null;
};

export type AgencySalaryLevelRow = {
  level: number;
  charm_target: number;
  charm_salary_usd: number;
  agent_salary_usd: number;
  is_active: boolean;
};

export type SalarySettings = {
  tiers: SalaryTierRow[];
  agencyLevels: AgencySalaryLevelRow[];
  diamondsPerDollar: number;
};

export type HostUsdEstimate = {
  hostTierUsd: number;
  hostTierName: string | null;
  charmSalaryUsd: number;
  charmLevel: number;
  /** Primary display: host tier reward (Targets) */
  estimatedUsd: number;
};

export type AgencyUsdEstimate = {
  charmSalaryUsd: number;
  agentSalaryUsd: number;
  totalUsd: number;
  level: number;
  totalCharm: number;
};

let settingsCache: { at: number; value: SalarySettings } | null = null;

export async function loadSalarySettings(): Promise<SalarySettings> {
  const now = Date.now();
  if (settingsCache && now - settingsCache.at < 30_000) {
    return settingsCache.value;
  }

  const [{ data: tiers }, { data: levels }, { data: chain }] = await Promise.all([
    supabaseAdmin
      .from('salary_tiers')
      .select(
        'id, tier_name, diamonds_target, hours_target, days_target, reward_amount, is_active',
      )
      .eq('is_active', true)
      .order('diamonds_target', { ascending: true }),
    supabaseAdmin
      .from('agency_salary_level_configs')
      .select(
        'level, charm_target, charm_salary_usd, agent_salary_usd, is_active',
      )
      .eq('is_active', true)
      .order('level', { ascending: true }),
    supabaseAdmin
      .from('salary_chain_configs')
      .select('diamonds_per_dollar')
      .eq('id', 1)
      .maybeSingle(),
  ]);

  const value: SalarySettings = {
    tiers: (tiers || []).map((t: any) => ({
      id: t.id,
      tier_name: t.tier_name,
      diamonds_target: Number(t.diamonds_target) || 0,
      hours_target: Number(t.hours_target) || 0,
      days_target: Number(t.days_target) || 0,
      reward_amount: Number(t.reward_amount) || 0,
      is_active: t.is_active,
    })),
    agencyLevels: (levels || []).map((l: any) => ({
      level: Number(l.level) || 0,
      charm_target: Number(l.charm_target) || 0,
      charm_salary_usd: Number(l.charm_salary_usd) || 0,
      agent_salary_usd: Number(l.agent_salary_usd) || 0,
      is_active: l.is_active !== false,
    })),
    diamondsPerDollar: Number(chain?.diamonds_per_dollar) || 1000,
  };

  settingsCache = { at: now, value };
  return value;
}

/** Flutter matchSalaryTier — highest tier where diamonds/hours/days all met. */
export function matchHostTier(
  tiers: SalaryTierRow[],
  stats: {
    total_diamonds?: number;
    total_on_mic_seconds?: number;
    valid_days?: number;
  } | null,
): SalaryTierRow | null {
  if (!stats || tiers.length === 0) return null;
  const diamonds = Number(stats.total_diamonds) || 0;
  const hours = Math.floor((Number(stats.total_on_mic_seconds) || 0) / 3600);
  const days = Number(stats.valid_days) || 0;

  let best: SalaryTierRow | null = null;
  for (const tier of tiers) {
    if (
      diamonds >= tier.diamonds_target &&
      hours >= tier.hours_target &&
      days >= tier.days_target
    ) {
      best = tier;
    }
  }
  return best;
}

/** DB match_agency_salary_level — highest level where charm_target <= charm. */
export function matchAgencyCharmLevel(
  levels: AgencySalaryLevelRow[],
  charm: number,
): AgencySalaryLevelRow | null {
  let best: AgencySalaryLevelRow | null = null;
  for (const level of levels) {
    if (charm >= level.charm_target) best = level;
  }
  return best;
}

export function estimateHostUsd(
  settings: SalarySettings,
  stats: {
    total_diamonds?: number;
    total_on_mic_seconds?: number;
    valid_days?: number;
    charm_points?: number;
  } | null,
): HostUsdEstimate {
  const tier = matchHostTier(settings.tiers, stats);
  const charmLevel = matchAgencyCharmLevel(
    settings.agencyLevels,
    Number(stats?.charm_points) || 0,
  );
  const hostTierUsd = tier?.reward_amount ?? 0;
  const charmSalaryUsd = charmLevel?.charm_salary_usd ?? 0;
  return {
    hostTierUsd,
    hostTierName: tier?.tier_name ?? (tier ? `Tier $${hostTierUsd}` : null),
    charmSalaryUsd,
    charmLevel: charmLevel?.level ?? 0,
    estimatedUsd: hostTierUsd,
  };
}

export function estimateAgencyUsd(
  settings: SalarySettings,
  hostCharms: number[],
): AgencyUsdEstimate {
  let totalCharm = 0;
  let charmSalaryUsd = 0;
  let agentSalaryUsd = 0;
  let level = 0;

  for (const rawCharm of hostCharms) {
    const charm = Number(rawCharm) || 0;
    totalCharm += charm;
    const matched = matchAgencyCharmLevel(settings.agencyLevels, charm);
    charmSalaryUsd += matched?.charm_salary_usd ?? 0;
    agentSalaryUsd += matched?.agent_salary_usd ?? 0;
    level = Math.max(level, matched?.level ?? 0);
  }

  return {
    charmSalaryUsd,
    agentSalaryUsd,
    totalUsd: charmSalaryUsd + agentSalaryUsd,
    level,
    totalCharm,
  };
}
