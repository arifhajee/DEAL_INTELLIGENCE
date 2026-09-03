/**
 * GET /api/admin/extraction-test?action=list_files&stage=<name>
 *   Lists files on a stage for the file picker
 * GET /api/admin/extraction-test?action=list_stages
 *   Lists configured ingestion stages
 * POST { filePath, stageName, mode }
 *   mode="full" — Parse → Classify → Sector → Resolve Schema → Extract (single file)
 *   mode="single_attr" — Parse → Extract one attribute only
 * POST { files: string[], stageName }
 *   Batch mode — runs full pipeline on multiple files from a stage
 */
import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { NextRequest } from "next/server"
import { requireAdmin, requireUser, escSql, badRequest, serverError } from "@/lib/api-utils"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const denied = await requireUser()
  if (denied) return denied

  const action = req.nextUrl.searchParams.get("action")

  if (action === "list_stages") {
    try {
      const rows = await querySnowflake(`
        SELECT stage_name, description
        FROM ${DB}.ADMIN.ingestion_stages
        WHERE is_active = TRUE
        ORDER BY stage_name
      `, { callersRights: true })
      return Response.json({ stages: rows })
    } catch (e) { return serverError(e) }
  }

  if (action === "list_files") {
    const stage = req.nextUrl.searchParams.get("stage")
    if (!stage) return badRequest("stage parameter is required")
    try {
      const stageRef = stage.startsWith("@") ? stage : `@${stage}`
      const rows = await querySnowflake(`LIST '${escSql(stageRef)}'`, { callersRights: true })
      const files = (rows as Record<string, unknown>[]).map(r => ({
        name: String(r.name ?? ""),
        size: Number(r.size ?? 0),
        last_modified: String(r.last_modified ?? ""),
      })).filter(f => {
        const ext = f.name.split(".").pop()?.toLowerCase() ?? ""
        return ["pdf", "png", "jpg", "jpeg", "tiff", "tif", "docx", "txt"].includes(ext)
      })
      return Response.json({ files })
    } catch (e) { return serverError(e) }
  }

  return badRequest("Unknown action. Use action=list_stages or action=list_files&stage=<name>")
}

// ─── Shared pipeline logic ─────────────────────────────────────────────────

async function parseDocument(stageName: string, filePath: string): Promise<string> {
  const stageRef = stageName.startsWith("@") ? stageName : `@${stageName}`
  // LIST returns paths like "stage_name/subdir/file.pdf"; PARSE_DOCUMENT needs relative path without the stage name prefix
  const stageShortName = stageName.replace(/^@/, "").split(".").pop() ?? ""
  const relPath = filePath.startsWith(stageShortName + "/") ? filePath.slice(stageShortName.length + 1) : filePath
  const parseRows = await querySnowflake(`
    SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
      '${escSql(stageRef)}',
      '${escSql(relPath)}',
      {'mode': 'LAYOUT'}
    ):content::VARCHAR AS content
  `, { callersRights: true })
  const row = parseRows[0] as Record<string, unknown>
  return String(row.CONTENT ?? row.content ?? "")
}

async function classifyDocument(safeText: string): Promise<{ primaryLabel: string; category: string }> {
  const labelRows = await querySnowflake(`
    SELECT label FROM ${DB}.ADMIN.classification_labels WHERE is_active = TRUE ORDER BY sort_order
  `, { callersRights: true })
  const labels = (labelRows as Record<string, unknown>[]).map(r => String(r.LABEL ?? r.label ?? ""))
  const labelsList = labels.map(l => `'${escSql(l)}'`).join(",")

  const classRows = await querySnowflake(`
    SELECT AI_CLASSIFY(
      '${safeText}',
      ARRAY_CONSTRUCT(${labelsList}),
      {'task_description': 'Classify this infrastructure PE document into the most appropriate category', 'output_mode': 'multi-label'}
    ) AS classification
  `, { callersRights: true })
  let classification = (classRows[0] as Record<string, unknown>).CLASSIFICATION ?? (classRows[0] as Record<string, unknown>).classification

  if (typeof classification === "string") {
    try { classification = JSON.parse(classification) } catch { /* */ }
  }

  let primaryLabel = ""
  try {
    if (classification && typeof classification === "object") {
      const obj = classification as Record<string, unknown>
      if (Array.isArray(obj.labels) && obj.labels.length > 0) {
        primaryLabel = String(obj.labels[0])
      } else if (obj.label) {
        primaryLabel = String(obj.label)
      }
    }
  } catch { /* */ }

  let category = ""
  if (primaryLabel) {
    const catRows = await querySnowflake(`
      SELECT category FROM ${DB}.ADMIN.classification_labels WHERE label = '${escSql(primaryLabel)}' LIMIT 1
    `, { callersRights: true })
    category = String((catRows[0] as Record<string, unknown>)?.CATEGORY ?? (catRows[0] as Record<string, unknown>)?.category ?? "")
  }

  return { primaryLabel, category }
}

async function detectSector(safeText: string): Promise<string> {
  // Read active sectors from config table
  const sectorRows = await querySnowflake(`
    SELECT sector_code, sector_name FROM ${DB}.ADMIN.investment_sectors
    WHERE is_active = TRUE ORDER BY sort_order
  `, { callersRights: true }) as Record<string, unknown>[]

  if (sectorRows.length === 0) return ""

  // Build display names for AI_CLASSIFY and mapping back to codes
  const displayNames = sectorRows.map(r => String(r.SECTOR_NAME ?? r.sector_name ?? ""))
  const nameToCode: Record<string, string> = {}
  for (const r of sectorRows) {
    const code = String(r.SECTOR_CODE ?? r.sector_code ?? "")
    const name = String(r.SECTOR_NAME ?? r.sector_name ?? "")
    nameToCode[name] = code
    nameToCode[code] = code // also map code to itself
  }

  const arrayStr = displayNames.map(n => `'${escSql(n)}'`).join(",")
  const sectorDetect = await querySnowflake(`
    SELECT AI_CLASSIFY(
      '${safeText.slice(0, 2000)}',
      ARRAY_CONSTRUCT(${arrayStr}),
      {'task_description': 'What infrastructure sector does this document relate to?'}
    ):labels[0]::VARCHAR AS sector
  `, { callersRights: true })
  const raw = String((sectorDetect[0] as Record<string, unknown>)?.SECTOR ?? (sectorDetect[0] as Record<string, unknown>)?.sector ?? "")
  // Map display name back to sector_code
  return nameToCode[raw] ?? raw
}

async function resolveSchemaAndExtract(safeText: string, category: string, sector: string) {
  const schemaRows = await querySnowflake(`
    SELECT attribute_name, attribute_description, attribute_type, schema_tier, document_type
    FROM ${DB}.ADMIN.extraction_schemas
    WHERE schema_tier = 'COMMON'
       OR (schema_tier = 'CATEGORY' AND PARSE_JSON(match_rule):category::VARCHAR = '${escSql(category)}')
       OR (schema_tier = 'SECTOR_SPECIFIC' AND PARSE_JSON(match_rule):category::VARCHAR = '${escSql(category)}'
           AND PARSE_JSON(match_rule):sector::VARCHAR = '${escSql(sector)}')
    ORDER BY CASE schema_tier WHEN 'COMMON' THEN 1 WHEN 'CATEGORY' THEN 2 ELSE 3 END, sort_order
  `, { callersRights: true })

  const extractSchema: Record<string, string> = {}
  const fieldTiers: Record<string, { tier: string; group: string }> = {}
  for (const row of schemaRows as Record<string, unknown>[]) {
    const name = String(row.ATTRIBUTE_NAME ?? row.attribute_name ?? "")
    const desc = String(row.ATTRIBUTE_DESCRIPTION ?? row.attribute_description ?? "")
    const tier = String(row.SCHEMA_TIER ?? row.schema_tier ?? "")
    const group = String(row.DOCUMENT_TYPE ?? row.document_type ?? "")
    if (name && !extractSchema[name]) {
      extractSchema[name] = desc
      fieldTiers[name] = { tier, group }
    }
  }

  let extraction: unknown = null
  if (Object.keys(extractSchema).length > 0) {
    const schemaJson = JSON.stringify(extractSchema).replace(/'/g, "''")
    const extractRows = await querySnowflake(`
      SELECT AI_EXTRACT('${safeText}', PARSE_JSON('${schemaJson}')) AS extraction
    `, { callersRights: true })
    extraction = (extractRows[0] as Record<string, unknown>).EXTRACTION ?? (extractRows[0] as Record<string, unknown>).extraction
  }

  return { extractSchema, fieldTiers, extraction, schemaFieldCount: Object.keys(extractSchema).length }
}

async function runFullPipeline(stageName: string, filePath: string): Promise<Record<string, unknown>> {
  const rawText = await parseDocument(stageName, filePath)
  const result: Record<string, unknown> = {
    filePath,
    raw_text_preview: rawText.slice(0, 500) + (rawText.length > 500 ? "..." : ""),
    full_text_length: rawText.length,
  }

  if (!rawText) {
    result.error = "No text extracted from document"
    return result
  }

  const safeText = rawText.slice(0, 8000).replace(/'/g, "''")
  const { primaryLabel, category } = await classifyDocument(safeText)
  result.primary_label = primaryLabel
  result.resolved_category = category

  const sector = await detectSector(safeText)
  result.resolved_sector = sector

  const { extractSchema, fieldTiers, extraction, schemaFieldCount } = await resolveSchemaAndExtract(safeText, category, sector)
  result.resolved_schema = extractSchema
  result.field_tiers = fieldTiers
  result.extraction = extraction
  result.schema_field_count = schemaFieldCount

  return result
}

// ─── POST handler ───────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  const denied = await requireAdmin()
  if (denied) return denied

  try {
    const body = await req.json()
    const { filePath, files, stageName, mode = "full", attributeName, attributeDescription } = body

    // ─── Mode: single_attr — test one attribute against a document ───────
    if (mode === "single_attr") {
      if (!filePath || !stageName || !attributeName || !attributeDescription) {
        return badRequest("filePath, stageName, attributeName, and attributeDescription are required for single_attr mode")
      }
      const rawText = await parseDocument(stageName, filePath)
      if (!rawText) return Response.json({ ok: true, value: null, error: "No text extracted" })

      const safeText = rawText.slice(0, 8000).replace(/'/g, "''")
      const schema = JSON.stringify({ [attributeName]: attributeDescription }).replace(/'/g, "''")
      const rows = await querySnowflake(`
        SELECT AI_EXTRACT('${safeText}', PARSE_JSON('${schema}')) AS extraction
      `, { callersRights: true })
      const extraction = (rows[0] as Record<string, unknown>).EXTRACTION ?? (rows[0] as Record<string, unknown>).extraction
      let parsed = extraction
      if (typeof parsed === "string") { try { parsed = JSON.parse(parsed) } catch { /* */ } }
      const value = parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>)[attributeName] ?? null : null
      return Response.json({ ok: true, value, attributeName })
    }

    // ─── Mode: batch — process multiple files from a stage ──────────────
    if (Array.isArray(files) && files.length > 0) {
      if (!stageName) return badRequest("stageName is required for batch mode")
      const results: Record<string, unknown>[] = []
      for (const fp of files.slice(0, 10)) { // cap at 10 files
        try {
          const r = await runFullPipeline(stageName, String(fp))
          results.push(r)
        } catch (e) {
          results.push({ filePath: fp, error: e instanceof Error ? e.message : "Processing failed" })
        }
      }
      return Response.json({ ok: true, results })
    }

    // ─── Mode: full — single file pipeline ──────────────────────────────
    if (!filePath) return badRequest("filePath is required")
    if (!stageName) return badRequest("stageName is required")

    if (mode === "classify_only") {
      const rawText = await parseDocument(stageName, filePath)
      if (!rawText) return Response.json({ ok: true, results: { filePath, error: "No text extracted" } })
      const safeText = rawText.slice(0, 8000).replace(/'/g, "''")
      const { primaryLabel, category } = await classifyDocument(safeText)
      return Response.json({ ok: true, results: { filePath, primary_label: primaryLabel, resolved_category: category } })
    }

    const results = await runFullPipeline(stageName, filePath)
    return Response.json({ ok: true, results })
  } catch (e) {
    return serverError(e)
  }
}
