import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { NextRequest } from "next/server"
import { escSql, requireAdmin, badRequest, serverError } from "@/lib/api-utils"

export const dynamic = "force-dynamic"

export async function GET() {
  const denied = await requireAdmin()
  if (denied) return denied
  try {
    const rows = await querySnowflake(`
      SELECT sector_code, sector_name, description, is_active, sort_order
      FROM ${DB}.ADMIN.investment_sectors
      ORDER BY sort_order, sector_name
    `, { callersRights: true })
    return Response.json({ sectors: rows })
  } catch (e) {
    return serverError(e)
  }
}

export async function POST(req: NextRequest) {
  const denied = await requireAdmin()
  if (denied) return denied
  try {
    const { sectorCode, sectorName, description } = await req.json()
    if (!sectorCode || !sectorName) return badRequest("sectorCode and sectorName are required")
    if (!/^[A-Za-z0-9_&]{1,50}$/.test(sectorCode)) return badRequest("sectorCode must be 1-50 alphanumeric characters (plus _ and &)")

    // Duplicate checks (case-insensitive) — UNIQUE constraints on standard tables aren't enforced by Snowflake
    const dupCode = await querySnowflake(`
      SELECT sector_code FROM ${DB}.ADMIN.investment_sectors
      WHERE UPPER(sector_code) = UPPER('${escSql(sectorCode)}')
    `, { callersRights: true })
    if (dupCode.length > 0) return Response.json({ error: "Sector code already exists" }, { status: 409 })

    const dupName = await querySnowflake(`
      SELECT sector_name FROM ${DB}.ADMIN.investment_sectors
      WHERE UPPER(sector_name) = UPPER('${escSql(sectorName)}')
    `, { callersRights: true })
    if (dupName.length > 0) return Response.json({ error: `Sector name "${sectorName}" already exists` }, { status: 409 })

    const maxOrder = await querySnowflake(`
      SELECT COALESCE(MAX(sort_order), 0) + 1 AS next_order FROM ${DB}.ADMIN.investment_sectors
    `, { callersRights: true })
    const nextOrder = Number((maxOrder[0] as Record<string, unknown>).NEXT_ORDER ?? (maxOrder[0] as Record<string, unknown>).next_order ?? 1)
    await querySnowflake(`
      INSERT INTO ${DB}.ADMIN.investment_sectors (sector_code, sector_name, description, sort_order, is_active)
      VALUES ('${escSql(sectorCode)}', '${escSql(sectorName)}', '${escSql(description ?? "")}', ${nextOrder}, TRUE)
    `, { callersRights: true })
    return Response.json({ ok: true })
  } catch (e) {
    return serverError(e)
  }
}

export async function PUT(req: NextRequest) {
  const denied = await requireAdmin()
  if (denied) return denied
  try {
    const body = await req.json()

    // Toggle active
    if (body.sectorCode && "isActive" in body) {
      await querySnowflake(`
        UPDATE ${DB}.ADMIN.investment_sectors
        SET is_active = ${body.isActive !== false}
        WHERE sector_code = '${escSql(body.sectorCode)}'
      `, { callersRights: true })
      return Response.json({ ok: true })
    }

    // Update Sector details
    if (body.sectorCode && body.sectorName) {
      if (!/^[A-Za-z0-9_&., -]{1,256}$/.test(body.sectorName)) return badRequest("sectorName contains invalid characters")
      const dupName = await querySnowflake(`
        SELECT sector_name FROM ${DB}.ADMIN.investment_sectors
        WHERE UPPER(sector_name) = UPPER('${escSql(body.sectorName)}')
          AND UPPER(sector_code) <> UPPER('${escSql(body.sectorCode)}')
      `, { callersRights: true })
      if (dupName.length > 0) return Response.json({ error: `Sector name "${body.sectorName}" already exists` }, { status: 409 })
      await querySnowflake(`
        UPDATE ${DB}.ADMIN.investment_sectors
        SET sector_name = '${escSql(body.sectorName)}',
            description = '${escSql(body.description ?? "")}'
        WHERE sector_code = '${escSql(body.sectorCode)}'
      `, { callersRights: true })
      return Response.json({ ok: true })
    }

    return badRequest("Invalid PUT body")
  } catch (e) {
    return serverError(e)
  }
}

export async function DELETE(req: NextRequest) {
  const denied = await requireAdmin()
  if (denied) return denied
  try {
    const sectorCode = req.nextUrl.searchParams.get("sector_code")
    if (!sectorCode) return badRequest("sector_code parameter is required")
    await querySnowflake(`
      DELETE FROM ${DB}.ADMIN.investment_sectors WHERE sector_code = '${escSql(sectorCode)}'
    `, { callersRights: true })
    return Response.json({ ok: true })
  } catch (e) {
    return serverError(e)
  }
}
