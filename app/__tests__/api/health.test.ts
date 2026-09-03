import { describe, it, expect, vi } from "vitest"

// Mock lib/snowflake before importing the route
vi.mock("@/lib/snowflake", () => ({
  querySnowflake: vi.fn().mockResolvedValue([{ 1: 1 }]),
}))

vi.mock("@/lib/db", () => ({ DB: "DEAL_INTEL" }))

describe("GET /api/health", () => {
  it("returns 200 with status ok when Snowflake is reachable", async () => {
    const { GET } = await import("@/app/api/health/route")
    const res = await GET()
    const json = await res.json()
    expect(res.status).toBe(200)
    expect(json.status).toBe("ok")
    expect(json.database).toBe("DEAL_INTEL")
    expect(typeof json.ts).toBe("string")
  })

  it("returns 503 when Snowflake throws", async () => {
    const { querySnowflake } = await import("@/lib/snowflake")
    vi.mocked(querySnowflake).mockRejectedValueOnce(new Error("connection refused"))
    const { GET } = await import("@/app/api/health/route")
    const res = await GET()
    expect(res.status).toBe(503)
    const json = await res.json()
    expect(json.status).toBe("error")
  })
})
