export const SECTOR_BADGE_COLORS: Record<string, string> = {
  "DINFRA": "sf-badge bg-indigo-100 text-indigo-700",
  "Digital Infrastructure": "sf-badge bg-indigo-100 text-indigo-700",
  "TRANS": "sf-badge bg-purple-100 text-purple-700",
  "Transportation & Logistics": "sf-badge bg-purple-100 text-purple-700",
  "ENERGY": "sf-badge bg-sky-100 text-sky-700",
  "Energy Transition": "sf-badge bg-sky-100 text-sky-700",
  "WATER": "sf-badge bg-green-100 text-green-700",
  "Water & Environmental": "sf-badge bg-green-100 text-green-700",
  "SOCIAL": "sf-badge bg-amber-100 text-amber-700",
  "Social Infrastructure": "sf-badge bg-amber-100 text-amber-700",
  "COMM": "sf-badge bg-orange-100 text-orange-700",
  "Communications": "sf-badge bg-orange-100 text-orange-700",
  "POWER": "sf-badge bg-slate-200 text-slate-700",
  "Conventional Power": "sf-badge bg-slate-200 text-slate-700",
  "MULTI": "sf-badge bg-rose-100 text-rose-700",
  "Multi-Sector Platform": "sf-badge bg-rose-100 text-rose-700",
}

export const STATUS_BADGE_COLORS: Record<string, string> = {
  active: "sf-badge bg-sky-100 text-sky-700",
  draft: "sf-badge bg-slate-100 text-slate-600",
  final: "sf-badge bg-emerald-100 text-emerald-700",
  approved: "sf-badge bg-emerald-100 text-emerald-700",
  "pending ic": "sf-badge bg-amber-100 text-amber-700",
  closed: "sf-badge bg-slate-100 text-slate-600",
  exited: "sf-badge bg-purple-100 text-purple-700",
  complete: "sf-badge bg-emerald-100 text-emerald-700",
  pending: "sf-badge bg-amber-100 text-amber-700",
  failed: "sf-badge bg-red-100 text-red-700",
}

export const DEFAULT_BADGE = "sf-badge bg-slate-100 text-slate-600"

export function sectorBadgeClass(sector: string): string {
  return SECTOR_BADGE_COLORS[sector] ?? DEFAULT_BADGE
}

export function statusBadgeClass(status: string): string {
  return STATUS_BADGE_COLORS[status.toLowerCase()] ?? DEFAULT_BADGE
}
