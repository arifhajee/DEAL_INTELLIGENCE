import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { requireUser, serverError } from "@/lib/api-utils"

export const dynamic = "force-dynamic"

export async function GET() {
  const denied = await requireUser()
  if (denied) return denied
  try {
    const [byType, bySector, byStatus, totalRow] = await Promise.all([
      querySnowflake(`
        SELECT document_type AS name, COUNT(*) AS value
        FROM ${DB}.DATA.document_catalog
        WHERE document_type IS NOT NULL
        GROUP BY 1 ORDER BY 2 DESC LIMIT 12
      `, { callersRights: true }),
      querySnowflake(`
        SELECT COALESCE(sector,'Unknown') AS name, COUNT(*) AS value
        FROM ${DB}.DATA.document_catalog
        GROUP BY 1 ORDER BY 2 DESC LIMIT 10
      `, { callersRights: true }),
      querySnowflake(`
        SELECT COALESCE(doc_status,'unknown') AS name, COUNT(*) AS value
        FROM ${DB}.DATA.document_catalog
        GROUP BY 1 ORDER BY 2 DESC
        LIMIT 50
      `, { callersRights: true }),
      querySnowflake(`
        SELECT COUNT(*) AS total,
               COUNT(DISTINCT sector) AS sectors
        FROM ${DB}.DATA.document_catalog
      `, { callersRights: true }),
    ])
    const norm = (rows: Record<string, unknown>[]) =>
      rows.map(r => ({ name: String(r.NAME ?? r.name ?? ""), value: Number(r.VALUE ?? r.value ?? 0) }))
    const total = Number((totalRow[0] as Record<string, unknown>)?.TOTAL ?? (totalRow[0] as Record<string, unknown>)?.total ?? 0)
    const sectorCount = Number((totalRow[0] as Record<string, unknown>)?.SECTORS ?? (totalRow[0] as Record<string, unknown>)?.sectors ?? 0)
    return Response.json({ byType: norm(byType), bySector: norm(bySector), byStatus: norm(byStatus), total, sectors: sectorCount })
  } catch (e) {
    console.error(new Date().toISOString(), "[analytics] error", e)
    return serverError(e)
  }
}
