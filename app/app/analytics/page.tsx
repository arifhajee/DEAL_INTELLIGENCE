"use client"

import { useEffect, useState } from "react"
import {
  BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, Tooltip,
  ResponsiveContainer, Legend
} from "recharts"
import { BarChart2, RefreshCw, Send, Copy, Code2 } from "lucide-react"
import { showToast } from "@/components/toast"
import { Spinner } from "@/components/spinner"
import { PageHeader } from "@/components/page-header"
import { StatCard, StatGrid } from "@/components/stat-card"

interface ChartData { name: string; value: number }
interface AnalyticsData {
  byType: ChartData[]; bySector: ChartData[]; byStatus: ChartData[]
  total?: number; sectors?: number
}
interface AnalystResult {
  answer: string
  sql: string | null
  results: Record<string, unknown>[]
  warnings?: { message: string }[]
}

const COLORS = ["#29B5E8","#11567F","#1A3A5C","#3B82F6","#0EA5E9","#2563EB","#7C3AED","#6D28D9"]
const STATUS_COLORS: Record<string, string> = {
  open: "#29B5E8", closed: "#94A3B8", active: "#22C55E",
  "pending ic": "#F59E0B", exited: "#8B5CF6", reserved: "#8B5CF6",
}



export default function AnalyticsPage() {
  const [data, setData]         = useState<AnalyticsData | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [loading, setLoading]   = useState(true)
  const [nlQuery, setNlQuery]   = useState("")
  const [nlResult, setNlResult] = useState<AnalystResult | null>(null)
  const [nlLoading, setNlLoading] = useState(false)
  const [showSql, setShowSql]   = useState(false)
  const [nlShowAll, setNlShowAll] = useState(false)

  async function loadData() {
    setLoading(true)
    setLoadError(null)
    try {
      const res = await fetch("/api/analytics")
      const d = await res.json()
      // Guard against error responses AND partial data crashing the page.
      // Each chart uses .slice() or .reduce() so ALL arrays must be present.
      if (!res.ok ||
          !Array.isArray(d?.byType)   ||
          !Array.isArray(d?.bySector)    ||
          !Array.isArray(d?.byStatus)) {
        setLoadError(d?.error ?? "Analytics failed to load")
      } else {
        setData(d as AnalyticsData)
      }
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : "Network error")
    } finally {
      setLoading(false)
    }
  }

  async function runNlQuery() {
    if (!nlQuery.trim()) return
    setNlLoading(true)
    setNlResult(null)   // clear stale result before new query renders
    setShowSql(false)
    try {
      const res = await fetch("/api/analyst", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question: nlQuery, history: [] }),
      })
      const d = await res.json()
      if (!res.ok) {
        showToast(d.error ?? "Analyst query failed", "error")
        setNlResult({ answer: `Error: ${d.error ?? "Request failed"}`, sql: null, results: [] })
      } else {
        setNlResult(d as AnalystResult)
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Unknown error"
      showToast(`Analytics query failed: ${msg}`, "error")
      setNlResult({ answer: `Error: ${msg}`, sql: null, results: [] })
    } finally {
      setNlLoading(false)
    }
  }

  useEffect(() => { loadData() }, [])

  const totalDocs  = data?.total ?? data?.byType.reduce((s, r) => s + r.value, 0) ?? 0
  const totalTypes = data?.byType.length ?? 0
  const sectorCount = data?.sectors ?? data?.bySector.length ?? 0

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      <PageHeader title="Portfolio Analytics" icon={BarChart2}>
        <button className="sf-btn-secondary flex items-center gap-1.5" onClick={loadData} disabled={loading}>
          {loading ? <Spinner size={13} /> : <RefreshCw size={13} />} Refresh
        </button>
      </PageHeader>

      <StatGrid>
        <StatCard label="Total Documents" value={totalDocs.toLocaleString()} />
        <StatCard label="Document Types" value={String(totalTypes)} sub="active taxonomy" />
        <StatCard label="Investment Sectors" value={String(sectorCount)} sub="specialty lines" />
        <StatCard label="Documents by Sector" value={String(data?.bySector.length ?? 0)} sub="active coverage areas" />
      </StatGrid>

      {/* NL Query */}
      <div className="sf-card p-4">
        <div className="flex items-center gap-2 mb-1">
          <BarChart2 size={15} className="text-[var(--brand-primary)]" />
          <h2 className="font-semibold text-slate-700 text-sm">Ask an Analytics Question</h2>
        </div>
        <p className="text-[10px] text-slate-400 mb-3 ml-[23px]">For counts, trends, and breakdowns — returns a data table via Cortex Analyst</p>
        <div className="flex gap-2">
          <input
            className="flex-1 text-sm px-3 py-2 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-[var(--brand-primary)]"
            placeholder="e.g. How many deals do we have by sector and deal stage?"
            value={nlQuery}
            maxLength={500}
            onChange={e => setNlQuery(e.target.value)}
            onKeyDown={e => e.key === "Enter" && !nlLoading && runNlQuery()}
            disabled={nlLoading}
          />
          <button className="sf-btn-primary flex items-center gap-1.5" onClick={runNlQuery} disabled={nlLoading}>
            <Send size={13} /> {nlLoading ? "…" : "Analyze"}
          </button>
        </div>
        {nlResult && (
          <div className="mt-3 space-y-2">
            {/* Prose answer */}
            <div className="relative p-3 rounded-lg bg-[var(--brand-pale)] border border-[var(--brand-border)] text-sm text-slate-700 whitespace-pre-wrap pr-10">
              {nlResult.answer}
              <button
                className="absolute top-2 right-2 p-1.5 rounded hover:bg-slate-200 text-slate-400 hover:text-slate-600 transition-colors"
                title="Copy answer"
                onClick={() => navigator.clipboard.writeText(nlResult.answer).then(
                          () => showToast("Copied to clipboard", "success"),
                          () => showToast("Copy failed — select text manually", "error")
                        )}
              ><Copy size={13} /></button>
            </div>

            {/* SQL toggle */}
            {nlResult.sql && (
              <div>
                <button
                  className="flex items-center gap-1 text-xs text-slate-500 hover:text-slate-700 transition-colors"
                  onClick={() => setShowSql(s => !s)}
                >
                  <Code2 size={11} /> {showSql ? "Hide SQL" : "Show generated SQL"}
                </button>
                {showSql && (
                  <div className="relative mt-1">
                    <pre className="bg-slate-900 text-slate-100 text-xs rounded-lg p-3 overflow-x-auto pr-10 leading-relaxed">
                      {nlResult.sql}
                    </pre>
                    <button
                      className="absolute top-2 right-2 p-1 rounded text-slate-400 hover:text-slate-200 transition-colors"
                      title="Copy SQL"
                      onClick={() => navigator.clipboard.writeText(nlResult.sql ?? "").then(
                          () => showToast("SQL copied", "success"),
                          () => showToast("Copy failed", "error")
                        )}
                    ><Copy size={11} /></button>
                  </div>
                )}
              </div>
            )}

            {/* Results table (first 10 rows) */}
            {nlResult.sql && (nlResult.results ?? []).length === 0 && (
              <p className="text-xs text-slate-400 mt-1 italic">Query executed — 0 rows returned</p>
            )}
            {nlResult.results?.length > 0 && (
              <div className="overflow-x-auto rounded-lg border border-slate-200">
                <table className="w-full text-xs">
                  <thead className="bg-slate-50 text-slate-600">
                    <tr>
                      {Object.keys(nlResult.results[0]).map(col => (
                        <th key={col} className="px-3 py-2 text-left font-medium">{col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {nlResult.results.slice(0, nlShowAll ? nlResult.results.length : 10).map((row, i) => (
                      <tr key={i} className="hover:bg-slate-50">
                        {Object.values(row).map((val, j) => (
                          <td key={j} className="px-3 py-1.5 text-slate-700 font-mono max-w-[160px] truncate" title={String(val ?? "")}>
                            {String(val ?? "")}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
                {nlResult.results.length > 10 && (
                  <div className="flex items-center gap-2 px-3 py-2 bg-slate-50 border-t border-slate-200">
                    <p className="text-xs text-slate-400">
                      Showing {nlShowAll ? nlResult.results.length : 10} of {nlResult.results.length} rows
                    </p>
                    <button onClick={() => setNlShowAll(!nlShowAll)} className="text-xs text-blue-600 hover:underline">
                      {nlShowAll ? "Show less" : "Show all"}
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Charts */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="sf-card p-5 animate-pulse">
              <div className="h-4 bg-slate-200 rounded w-32 mb-4" />
              <div className="h-40 bg-slate-100 rounded" />
            </div>
          ))}
        </div>
      ) : loadError ? (
        <div className="sf-card p-8 text-center">
          <p className="text-slate-600 font-medium mb-1">Failed to load analytics</p>
          <p className="text-xs text-slate-400 mb-4 font-mono">{loadError}</p>
          <button className="sf-btn-primary text-sm" onClick={loadData}>Retry</button>
        </div>
      ) : data ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {/* By Document Type */}
          <div className="sf-card p-5">
            <h2 className="font-semibold text-slate-700 mb-4 text-sm">Documents by Type</h2>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={data.byType.slice(0, 10)} layout="vertical" margin={{ left: 10 }}>
                <XAxis type="number" tick={{ fontSize: 11 }} />
                <YAxis type="category" dataKey="name" tick={{ fontSize: 10 }} width={160} />
                <Tooltip />
                <Bar dataKey="value" fill="#29B5E8" radius={[0,4,4,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* By Sector */}
          <div className="sf-card p-5">
            <h2 className="font-semibold text-slate-700 mb-4 text-sm">Sector</h2>
            <ResponsiveContainer width="100%" height={260}>
              <PieChart>
                <Pie data={data.bySector} dataKey="value" nameKey="name" cx="50%" cy="50%" innerRadius={60} outerRadius={100}>
                  {data.bySector.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Pie>
                <Tooltip />
                <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
              </PieChart>
            </ResponsiveContainer>
          </div>

          {/* By Sector - Bar Chart */}
          <div className="sf-card p-5">
            <h2 className="font-semibold text-slate-700 mb-4 text-sm">Documents by Sector</h2>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={data.bySector} margin={{ bottom: 5 }}>
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Bar dataKey="value" radius={[4,4,0,0]}>
                  {data.bySector.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* By Status */}
          <div className="sf-card p-5">
            <h2 className="font-semibold text-slate-700 mb-4 text-sm">Document Status</h2>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={data.byStatus} margin={{ bottom: 5 }}>
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Bar dataKey="value" radius={[4,4,0,0]}>
                  {data.byStatus.map((d) => (
                    <Cell key={d.name} fill={STATUS_COLORS[d.name] ?? "#94A3B8"} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      ) : null}
    </div>
  )
}
