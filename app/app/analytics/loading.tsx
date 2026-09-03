export default function AnalyticsLoading() {
  return (
    <div className="max-w-6xl mx-auto space-y-5 animate-pulse">
      <div className="flex items-center justify-between">
        <div className="h-6 bg-slate-200 rounded w-48" />
        <div className="h-8 bg-slate-100 rounded w-20" />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="sf-card p-4">
            <div className="h-3 bg-slate-200 rounded w-24 mb-2" />
            <div className="h-7 bg-slate-200 rounded w-16" />
          </div>
        ))}
      </div>
      <div className="sf-card p-4">
        <div className="h-4 bg-slate-200 rounded w-48 mb-3" />
        <div className="h-10 bg-slate-100 rounded" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="sf-card p-5">
            <div className="h-4 bg-slate-200 rounded w-40 mb-4" />
            <div className="h-48 bg-slate-100 rounded" />
          </div>
        ))}
      </div>
    </div>
  )
}
