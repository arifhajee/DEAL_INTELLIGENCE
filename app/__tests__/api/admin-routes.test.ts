import { describe, it, expect, vi, beforeEach } from "vitest"

vi.mock("@/lib/db", () => ({ DB: "DEAL_INTEL" }))
vi.mock("@/lib/snowflake", () => ({ querySnowflake: vi.fn() }))
vi.mock("@/lib/api-utils", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api-utils")>()
  return { ...actual, requireAdmin: vi.fn().mockResolvedValue(null) }
})

describe("GET /api/cost", () => {
  beforeEach(() => { vi.clearAllMocks(); vi.resetModules() })

  it("returns byFolder, byStage, and KPI fields", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake)
      .mockResolvedValueOnce([{ NAME: "Claims", VALUE: 1.5  }])     // byFolder
      .mockResolvedValueOnce([{ NAME: "PARSE",  VALUE: 0.3  }])     // byStage
      .mockResolvedValueOnce([{ TOTAL_7D: 5.2, AVG_DAILY: 0.74, PROJECTED_MONTHLY: 22.3 }])
    const { GET } = await import("@/app/api/cost/route")
    const res = await GET()
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(Array.isArray(body.byFolder)).toBe(true)
    expect(Array.isArray(body.byStage)).toBe(true)
    expect(typeof body.total7d).toBe("number")
    expect(typeof body.avgDaily).toBe("number")
    expect(typeof body.projectedMonthly).toBe("number")
  })

  it("returns 500 on Snowflake error", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockRejectedValue(new Error("access denied"))
    const { GET } = await import("@/app/api/cost/route")
    const res = await GET()
    expect(res.status).toBe(500)
  })
})

describe("GET /api/quality", () => {
  beforeEach(() => { vi.clearAllMocks(); vi.resetModules() })

  it("returns metrics, corrections, and feedback arrays", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake)
      .mockResolvedValueOnce([{ AVG_CONFIDENCE: 0.91, LOW_CONFIDENCE_PCT: 0.05, LOW_CONFIDENCE_COUNT: 3, DOC_COUNT: 60, IR_MATCH_PCT: 0.88, IR_MATCH_COUNT: 53 }])
      .mockResolvedValueOnce([{ OVERRIDE_ID: "1", FILE_PATH: "docs/a.pdf", FIELD_NAME: "doc_status" }])
      .mockResolvedValueOnce([{ FEEDBACK_ID: "1", FEEDBACK_TYPE: "thumbs_up" }])
    const { GET } = await import("@/app/api/quality/route")
    const res = await GET()
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.avgConfidence).toBeCloseTo(0.91)
    expect(body.irMatchPct).toBeCloseTo(0.88)
    expect(Array.isArray(body.corrections)).toBe(true)
    expect(Array.isArray(body.feedback)).toBe(true)
  })

  it("returns 500 on error", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockRejectedValue(new Error("timeout"))
    const { GET } = await import("@/app/api/quality/route")
    const res = await GET()
    expect(res.status).toBe(500)
  })
})
