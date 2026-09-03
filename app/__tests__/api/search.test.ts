import { describe, it, expect, vi, beforeEach } from "vitest"

vi.mock("@/lib/db", () => ({ DB: "DEAL_INTEL" }))
vi.mock("@/lib/snowflake", () => ({ querySnowflake: vi.fn() }))
vi.mock("@/lib/api-utils", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api-utils")>()
  return { ...actual, requireUser: vi.fn().mockResolvedValue(null) }
})

describe("GET /api/search", () => {
  beforeEach(() => { vi.clearAllMocks(); vi.resetModules() })

  it("returns empty array when query is blank", async () => {
    const { GET } = await import("@/app/api/search/route")
    const req = new Request("http://localhost/api/search?q=")
    const res = await GET(req as never)
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual([])
  })

  it("builds Cortex Search payload with filters", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockResolvedValue([{ RESULTS: [{ document_type: "IC Presentation" }] }])
    const { GET } = await import("@/app/api/search/route")
    const req = new Request("http://localhost/api/search?q=cyber+claim&folder=Claims&limit=5")
    const res = await GET(req as never)
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
    // Verify SQL was called (Cortex Search preview query)
    expect(vi.mocked(querySnowflake)).toHaveBeenCalledOnce()
    const [sql] = vi.mocked(querySnowflake).mock.calls[0]
    expect(sql).toContain("SEARCH_PREVIEW")
    expect(sql).toContain("cyber claim")
  })

  it("clamps limit to 50 max", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockResolvedValue([{ RESULTS: [] }])
    const { GET } = await import("@/app/api/search/route")
    const req = new Request("http://localhost/api/search?q=test&limit=9999")
    await GET(req as never)
    const [sql] = vi.mocked(querySnowflake).mock.calls[0]
    // The payload JSON embeds the limit — should be 50, not 9999
    expect(sql).toContain('"limit":50')
  })

  it("returns 500 with error message when Snowflake throws", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockRejectedValue(new Error("network timeout"))
    const { GET } = await import("@/app/api/search/route")
    const req = new Request("http://localhost/api/search?q=test")
    const res = await GET(req as never)
    expect(res.status).toBe(500)
    const body = await res.json()
    expect(body.error).toContain("network timeout")
  })
})
