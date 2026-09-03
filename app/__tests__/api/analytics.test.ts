import { describe, it, expect, vi, beforeEach } from "vitest"

vi.mock("@/lib/db", () => ({ DB: "DEAL_INTEL" }))
vi.mock("@/lib/snowflake", () => ({ querySnowflake: vi.fn() }))
vi.mock("@/lib/api-utils", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api-utils")>()
  return { ...actual, requireUser: vi.fn().mockResolvedValue(null), requireAdmin: vi.fn().mockResolvedValue(null) }
})

describe("GET /api/analytics", () => {
  beforeEach(() => { vi.clearAllMocks(); vi.resetModules() })

  it("returns all four chart arrays with correct keys", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    // Route destructures as: [byType, bySector, byFolder, byStatus] — match this order
    vi.mocked(querySnowflake)
      .mockResolvedValueOnce([{ NAME: "IC Presentation",   VALUE: 50  }])  // byType  (index 0)
      .mockResolvedValueOnce([{ NAME: "Energy Transition",  VALUE: 30  }])  // bySector   (index 1)
      .mockResolvedValueOnce([{ NAME: "Claims", VALUE: 100 }])  // byFolder (index 2)
      .mockResolvedValueOnce([{ NAME: "open",   VALUE: 80  }])  // byStatus (index 3)
    const { GET } = await import("@/app/api/analytics/route")
    const res = await GET()
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(Array.isArray(body.byFolder)).toBe(true)
    expect(Array.isArray(body.byType)).toBe(true)
    expect(Array.isArray(body.bySector)).toBe(true)
    expect(Array.isArray(body.byStatus)).toBe(true)
    // Verify each array got the right mock data
    expect(body.byType[0].name).toBe("IC Presentation")
    expect(body.bySector[0].name).toBe("Energy Transition")
    expect(body.byFolder[0].name).toBe("Claims")
    expect(body.byStatus[0].name).toBe("open")
  })

  it("normalises NAME/VALUE columns to name/value", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockResolvedValue([{ NAME: "Digital Infrastructure", VALUE: 42 }])
    const { GET } = await import("@/app/api/analytics/route")
    const body = await (await GET()).json()
    expect(body.byType[0]).toEqual({ name: "Digital Infrastructure", value: 42 })
  })

  it("returns 500 on Snowflake error", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockRejectedValue(new Error("warehouse suspended"))
    const { GET } = await import("@/app/api/analytics/route")
    const res = await GET()
    expect(res.status).toBe(500)
    expect((await res.json()).error).toContain("warehouse suspended")
  })
})
