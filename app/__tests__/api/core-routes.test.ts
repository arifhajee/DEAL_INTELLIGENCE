import { describe, it, expect, vi, beforeEach } from "vitest"

// Mock Snowflake and DB before any imports
vi.mock("@/lib/db", () => ({ DB: "DEAL_INTEL" }))
vi.mock("@/lib/snowflake", () => ({
  querySnowflake: vi.fn(),
}))
vi.mock("@/lib/api-utils", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api-utils")>()
  return { ...actual, requireUser: vi.fn().mockResolvedValue(null), requireAdmin: vi.fn().mockResolvedValue(null) }
})

describe("API routes — basic shape tests", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.resetModules()
  })

  describe("GET /api/filters", () => {
    it("returns empty lists when DB returns no rows", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([])
      const { GET } = await import("@/app/api/filters/route")
      const res = await GET()
      const json = await res.json()
      expect(res.status).toBe(200)
      expect(Array.isArray(json.folders)).toBe(true)
      expect(Array.isArray(json.sectors)).toBe(true)
      expect(Array.isArray(json.formats)).toBe(true)
    })

    it("returns distinct values from DB rows", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      // First call returns folders, rest return empty
      vi.mocked(querySnowflake)
        .mockResolvedValueOnce([{ VALUE: "Claims" }, { VALUE: "Underwriting" }])
        .mockResolvedValue([])
      const { GET } = await import("@/app/api/filters/route")
      const res = await GET()
      const json = await res.json()
      expect(json.folders).toContain("Claims")
      expect(json.folders).toContain("Underwriting")
    })
  })

  describe("GET /api/auth", () => {
    it("returns user role info", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([{
        USER_NAME: "test.user",
        CURRENT_ROLE: "DEAL_INTEL_USER",
        ACCOUNT: "TESTACCOUNT",
        IS_ADMIN: false,
        IS_USER: true,
        ACCESS_DEALS: false,
        ACCESS_SOURCING: false,
        ACCESS_IR: false,
        ACCESS_COMPLIANCE: false,
        IS_PIPELINE: false,
      }])
      const { GET } = await import("@/app/api/auth/route")
      const res = await GET()
      const json = await res.json()
      expect(res.status).toBe(200)
      expect(json.userName).toBe("test.user")
      expect(json.appRole).toBe("user")
      expect(json.isAdmin).toBe(false)
    })

    it("returns admin role when IS_ADMIN is true", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([{
        USER_NAME: "admin.user",
        CURRENT_ROLE: "DEAL_INTEL_ADMIN",
        ACCOUNT: "TESTACCOUNT",
        IS_ADMIN: true,
        IS_USER: false,
        ACCESS_DEALS: false,
        ACCESS_SOURCING: false,
        ACCESS_IR: false,
        ACCESS_COMPLIANCE: false,
        IS_PIPELINE: false,
      }])
      const { GET } = await import("@/app/api/auth/route")
      const res = await GET()
      const json = await res.json()
      expect(json.appRole).toBe("admin")
      expect(json.isAdmin).toBe(true)
    })

    it("fails closed with none role when DB throws", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockRejectedValue(new Error("timeout"))
      const { GET } = await import("@/app/api/auth/route")
      const res = await GET()
      expect(res.status).toBe(200)
      const json = await res.json()
      // FAIL CLOSED: errors return none, not user, to prevent accidental access grants
      expect(json.appRole).toBe("none")
      expect(json.error).toBeDefined()
    })
  })

  describe("POST /api/admin — action routing", () => {
    it("returns 400 for unknown action", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([])
      const { POST } = await import("@/app/api/admin/route")
      const req = new Request("http://localhost/api/admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "unknown_action" }),
      })
      const res = await POST(req as never)
      expect(res.status).toBe(400)
    })

    it("returns 400 for force_reprocess without filePath", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([])
      const { POST } = await import("@/app/api/admin/route")
      const req = new Request("http://localhost/api/admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "force_reprocess" }),
      })
      const res = await POST(req as never)
      expect(res.status).toBe(400)
    })

    it("returns ok:true for valid force_reprocess", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([{ STATUS: "OK" }])
      const { POST } = await import("@/app/api/admin/route")
      const req = new Request("http://localhost/api/admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "force_reprocess", filePath: "documents/test.pdf" }),
      })
      const res = await POST(req as never)
      expect(res.status).toBe(200)
      const json = await res.json()
      expect(json.ok).toBe(true)
    })

    it("handles submit_correction action", async () => {
      const { querySnowflake } = await import("@/lib/snowflake")
      vi.mocked(querySnowflake).mockResolvedValue([])
      const { POST } = await import("@/app/api/admin/route")
      const req = new Request("http://localhost/api/admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "submit_correction",
          filePath: "documents/test.pdf",
          fieldName: "target_company",
          originalValue: "Wrong Name",
          correctedValue: "Correct Name",
        }),
      })
      const res = await POST(req as never)
      expect(res.status).toBe(200)
      const json = await res.json()
      expect(json.ok).toBe(true)
    })
  })
})
