/**
 * Entitlements helper — multi-role resolution.
 *
 * Users get access EXCLUSIVELY from role membership (no custom/direct entitlements).
 * A user can be a member of multiple roles. Effective access = union of all roles' arrays.
 *
 * Resolution:
 * 1. Load all active role assignments for the user from user_role_assignments
 * 2. For each role, load arrays (menu_access, sector_access, doc_type_access, can_download)
 * 3. UNION all arrays: if any contains "*", result is ["*"] (wildcard wins)
 * 4. canDownload = true if ANY role allows it
 * 5. If no assignments, return defaults (all access)
 */
import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { escSql } from "@/lib/api-utils"

export interface Entitlements {
  menuAccess: string[]
  sectorAccess: string[]
  docTypeAccess: string[]
  appRole: "admin" | "user" | "viewer"
  canDownload: boolean
  isActive: boolean
  roleName: string | null
}

/** Admin page keys — if any are present in menuAccess, user has admin role */
const ADMIN_KEYS = [
  "admin:pipeline", "admin:registry", "admin:quality", "admin:cost",
  "admin:extraction", "admin:labels", "admin:notifications", "admin:config",
  "admin:audit", "admin:users",
]

const DEFAULT_MENU = ["dashboard", "search", "chat", "analytics", "documents", "saved", "review", "help"]

const DEFAULT_ENTITLEMENTS: Entitlements = {
  menuAccess: DEFAULT_MENU,
  sectorAccess: ["*"],
  docTypeAccess: ["*"],
  appRole: "user",
  canDownload: true,
  isActive: true,
  roleName: null,
}

/**
 * Fetch entitlements for a specific user with multi-role union resolution.
 */
export async function getUserEntitlements(userName: string): Promise<Entitlements> {
  try {
    // First check if user is deactivated
    const userRows = await querySnowflake(`
      SELECT app_role, is_active
      FROM ${DB}.ADMIN.user_entitlements
      WHERE UPPER(user_name) = UPPER('${escSql(userName)}')
      LIMIT 1
    `)

    if (userRows && userRows.length > 0) {
      const u = userRows[0] as Record<string, unknown>
      const isActive = u.IS_ACTIVE !== false && u.is_active !== false &&
                       u.IS_ACTIVE !== "false" && u.is_active !== "false"
      if (!isActive) {
        return { ...DEFAULT_ENTITLEMENTS, isActive: false, menuAccess: [], sectorAccess: [], docTypeAccess: [] }
      }
    }

    // Load all role assignments with role details in one query
    const rows = await querySnowflake(`
      SELECT
        r.role_name,
        r.menu_access,
        r.sector_access,
        r.doc_type_access,
        r.can_download
      FROM ${DB}.ADMIN.user_role_assignments a
      JOIN ${DB}.ADMIN.entitlement_roles r
        ON a.role_id = r.role_id AND r.is_active = TRUE
      WHERE UPPER(a.user_name) = UPPER('${escSql(userName)}')
    `)

    if (!rows || rows.length === 0) {
      // No roles assigned — return defaults
      return DEFAULT_ENTITLEMENTS
    }

    // Union all role arrays
    const allMenus = new Set<string>()
    const allSectors = new Set<string>()
    const allDocs = new Set<string>()
    let canDownload = false
    const roleNames: string[] = []

    for (const row of rows) {
      const r = row as Record<string, unknown>
      roleNames.push(String(r.ROLE_NAME ?? r.role_name ?? ""))

      const menu = parseArray(r.MENU_ACCESS ?? r.menu_access)
      const sector = parseArray(r.SECTOR_ACCESS ?? r.sector_access)
      const doc = parseArray(r.DOC_TYPE_ACCESS ?? r.doc_type_access)
      const download = r.CAN_DOWNLOAD !== false && r.can_download !== false

      menu.forEach(m => allMenus.add(m))
      sector.forEach(l => allSectors.add(l))
      doc.forEach(d => allDocs.add(d))
      if (download) canDownload = true
    }

    // Wildcard wins — if any role grants "*", effective access is all
    const menuAccess = allMenus.has("*") ? DEFAULT_MENU : Array.from(allMenus)
    const sectorAccess = allSectors.has("*") ? ["*"] : Array.from(allSectors)
    const docTypeAccess = allDocs.has("*") ? ["*"] : Array.from(allDocs)

    // Derive appRole from effective menuAccess — admin keys present = admin
    const hasAdminKeys = ADMIN_KEYS.some(k => menuAccess.includes(k))
    const appRole: "admin" | "user" | "viewer" = hasAdminKeys ? "admin" : "user"

    return {
      appRole,
      menuAccess,
      sectorAccess,
      docTypeAccess,
      canDownload,
      isActive: true,
      roleName: roleNames.join(", "),
    }
  } catch (e) {
    console.error("[entitlements] Failed to fetch for", userName, e)
    return { ...DEFAULT_ENTITLEMENTS, sectorAccess: [], docTypeAccess: [], menuAccess: [], canDownload: false, isActive: false }
  }
}

/**
 * Build a SQL WHERE clause fragment for sector filtering.
 */
export function sectorFilter(entitlements: Entitlements, column: string = "sector"): string {
  if (entitlements.sectorAccess.includes("*")) return ""
  if (entitlements.sectorAccess.length === 0) return ` AND 1=0`
  const values = entitlements.sectorAccess.map(v => `'${v.replace(/'/g, "''")}'`).join(",")
  return ` AND ${column} IN (${values})`
}

/**
 * Build a SQL WHERE clause fragment for document type filtering.
 */
export function docTypeFilter(entitlements: Entitlements, column: string = "document_type"): string {
  if (entitlements.docTypeAccess.includes("*")) return ""
  if (entitlements.docTypeAccess.length === 0) return ` AND 1=0`
  const values = entitlements.docTypeAccess.map(v => `'${v.replace(/'/g, "''")}'`).join(",")
  return ` AND ${column} IN (${values})`
}

// --- Internal helpers ---

function parseArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String).filter(Boolean)
  if (typeof value === "string") {
    try {
      const arr = JSON.parse(value)
      if (Array.isArray(arr)) return arr.map(String).filter(Boolean)
    } catch { /* fall through */ }
  }
  return []
}


