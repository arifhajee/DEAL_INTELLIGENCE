"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useState, useEffect } from "react"
import { THEME } from "@/theme.config"
import { useRole } from "@/hooks/use-role"
import {
  Home, Search, MessageSquare, FolderOpen, Bookmark,
  Settings, Activity, DollarSign, ClipboardList, CheckSquare, Shield, Users, Code, ClipboardCheck, HelpCircle, Tags, Bell, Bot, Briefcase
} from "lucide-react"

const navItems = [
  { href: "/",          icon: Home,            label: "Overview",                sub: "Pipeline health & activity",     key: "dashboard" },
  { href: "/documents", icon: FolderOpen,      label: "Document Browser",        sub: "Filter by type, sector, status",    key: "documents" },
  { href: "/search",    icon: Search,          label: "Document Search",         sub: "Find by content — AI search",    key: "search" },
  { href: "/review",    icon: ClipboardCheck,  label: "Review Queue",            sub: null,                              key: "review" },
  { href: "/chat",      icon: Bot,             label: "Doc Intelligence",        sub: "Ask about documents & data",     key: "chat" },

  { href: "/saved",     icon: Bookmark,        label: "Saved Items",             sub: null,                              key: "saved" },
  { href: "/help",      icon: HelpCircle,      label: "Help",                    sub: null,                              key: "help" },
]

const adminItems = [
  // Operations
  { href: "/admin/pipeline",  icon: Activity,       label: "Pipeline Management",    key: "admin:pipeline", group: "operations" },
  { href: "/admin/registry",  icon: ClipboardList,  label: "Ingestion Registry", key: "admin:registry", group: "operations" },
  { href: "/admin/quality",   icon: CheckSquare,    label: "Quality & Feedback", key: "admin:quality", group: "operations" },
  { href: "/admin/cost",      icon: DollarSign,     label: "Cost Dashboard",     key: "admin:cost", group: "operations" },
  // AI Configuration
  { href: "/admin/extraction-schema", icon: Code,   label: "Extraction Schema",  key: "admin:extraction", group: "ai" },
  { href: "/admin/classification-labels", icon: Tags, label: "Classification Labels", key: "admin:labels", group: "ai" },
  { href: "/admin/sectors", icon: Briefcase, label: "Investment Sectors", key: "admin:sectors", group: "ai" },
  // Management
  { href: "/admin/notifications", icon: Bell,       label: "Notifications",      key: "admin:notifications", group: "manage" },
  { href: "/admin/config",    icon: Settings,       label: "Configuration",      key: "admin:config", group: "manage" },
  { href: "/admin/audit",     icon: Shield,         label: "Audit Log",          key: "admin:audit", group: "manage" },
  { href: "/admin/users",     icon: Users,          label: "User Management",    key: "admin:users", group: "manage" },
]

function isActive(href: string, pathname: string) {
  if (href === "/") return pathname === "/"
  return pathname === href || pathname.startsWith(href + "/")
}

export function AppSidebar() {
  const pathname = usePathname()
  const { isAdmin, userName, loading, appRole, entitlements } = useRole()
  const [reviewPending, setReviewPending] = useState(0)

  // Fetch review queue pending count for badge
  useEffect(() => {
    if (!loading) {
      fetch("/api/review?action=count")
        .then(r => r.json())
        .then(d => setReviewPending(Number(d.pending ?? 0)))
        .catch(() => {})
    }
  }, [loading])

  // Filter nav items by user's menu entitlements (applies to all roles including admin)
  const visibleNavItems = navItems.filter(item => {
    if (loading) return true // show all while loading
    if (!entitlements) return true // no entitlements = show all (fail-open for UI)
    return entitlements.menuAccess.includes(item.key)
  })

  return (
    <aside className="w-60 bg-white border-r border-slate-200 flex flex-col shrink-0">
      {/* Brand */}
      <div className="px-5 py-4 border-b border-slate-100">
        <div className="flex items-center gap-2.5">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={THEME.logoUrl} alt={THEME.appName} className="w-7 h-7" />
          <div>
            <p className="font-bold text-sm leading-tight" style={{ color: "var(--brand-primary)" }}>
              {THEME.appName}
            </p>
            <p className="text-[10px] text-slate-400 leading-tight">{THEME.appSubtitle}</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {visibleNavItems.map(({ href, icon: Icon, label, sub, key }) => (
          <Link
            key={href}
            href={href}
            prefetch={false}
            className={`nav-link ${isActive(href, pathname) ? "active" : ""}`}
            title={sub ?? undefined}
          >
            <Icon size={16} />
            <span className="flex-1 truncate">{label}</span>
            {key === "review" && reviewPending > 0 && (
              <span className="ml-auto text-[9px] font-bold bg-amber-500 text-white px-1.5 py-0.5 rounded-full">
                {reviewPending}
              </span>
            )}
          </Link>
        ))}

        {/* Admin section — filtered by entitlement role menu_access */}
        {!loading && (() => {
          const visibleAdminItems = adminItems.filter(item => {
            if (!entitlements) return isAdmin // fallback: use Snowflake role check
            return entitlements.menuAccess.includes(item.key)
          })
          if (visibleAdminItems.length === 0) return null
          return (
            <>
              <div className="pt-4 pb-1 px-3">
                <p className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                  <Shield size={11} /> Admin
                </p>
              </div>
              {(() => {
                const groups = [
                  { id: "operations", label: "Operations" },
                  { id: "ai", label: "AI Config" },
                  { id: "manage", label: "Management" },
                ]
                return groups.map(g => {
                  const items = visibleAdminItems.filter(i => i.group === g.id)
                  if (items.length === 0) return null
                  return (
                    <div key={g.id}>
                      {g.id !== "operations" && (
                        <p className="text-[9px] text-slate-400 uppercase tracking-wider px-3 pt-2 pb-0.5">{g.label}</p>
                      )}
                      {items.map(({ href, icon: Icon, label }) => (
                        <Link
                          key={href}
                          href={href}
                          prefetch={false}
                          className={`nav-link ${isActive(href, pathname) ? "active" : ""}`}
                        >
                          <Icon size={16} />
                          {label}
                        </Link>
                      ))}
                    </div>
                  )
                })
              })()}
            </>
          )
        })()}

        {/* Placeholder while loading roles */}
        {loading && (
          <div className="pt-4 animate-pulse space-y-1">
            {[1, 2].map(i => (
              <div key={i} className="h-8 bg-slate-100 rounded-lg mx-1" />
            ))}
          </div>
        )}
      </nav>
    </aside>
  )
}
