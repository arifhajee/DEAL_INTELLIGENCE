/**
 * GET /api/documents/related?id=<base64url file_path>
 */
import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { NextRequest } from "next/server"
import { requireUser, escSql, badRequest, serverError } from "@/lib/api-utils"

export const dynamic = "force-dynamic"

function decodeId(id: string): string {
  return Buffer.from(id.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf-8")
}

export async function GET(req: NextRequest) {
  const denied = await requireUser()
  if (denied) return denied

  const id = req.nextUrl.searchParams.get("id")
  if (!id) return badRequest("id parameter is required")
  const filePath = decodeId(id)

  try {
    const docRows = await querySnowflake(`
      SELECT target_company, deal_code, fund_name
      FROM ${DB}.DATA.document_catalog
      WHERE file_path = '${escSql(filePath)}'
      LIMIT 1
    `, { callersRights: true })

    if (!docRows || docRows.length === 0) {
      return Response.json({ related: [] })
    }

    const doc = docRows[0] as Record<string, unknown>
    const insured = String(doc.TARGET_COMPANY ?? doc.target_company ?? "")
    const policy = String(doc.DEAL_CODE ?? doc.deal_code ?? "")
    const claim = String(doc.FUND_NAME ?? doc.fund_name ?? "")

    const conditions: string[] = []
    if (insured) conditions.push(`target_company = '${escSql(insured)}'`)
    if (policy) conditions.push(`deal_code = '${escSql(policy)}'`)
    if (claim) conditions.push(`fund_name = '${escSql(claim)}'`)

    if (conditions.length === 0) {
      return Response.json({ related: [] })
    }

    const rows = await querySnowflake(`
      SELECT file_path, document_type, target_company, deal_code,
             fund_name, sector, classification_confidence, ingestion_status
      FROM ${DB}.DATA.document_catalog
      WHERE file_path != '${escSql(filePath)}'
        AND (${conditions.join(" OR ")})
      ORDER BY processing_completed_at DESC NULLS LAST
      LIMIT 20
    `, { callersRights: true })

    return Response.json({ related: rows })
  } catch (e) {
    return serverError(e)
  }
}
