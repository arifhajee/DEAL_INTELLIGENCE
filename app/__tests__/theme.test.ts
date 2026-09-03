import { describe, it, expect, vi, beforeEach, afterEach } from "vitest"

describe("THEME config defaults", () => {
  beforeEach(() => {
    vi.resetModules()
  })

  afterEach(() => {
    // Clean up any env mutations
    delete process.env.NEXT_PUBLIC_APP_NAME
    delete process.env.NEXT_PUBLIC_BRAND_COLOR
    delete process.env.DEAL_INTEL_DATABASE
  })

  it("falls back to DealIntel defaults when env vars not set", async () => {
    const { THEME } = await import("@/theme.config")
    expect(THEME.appName).toBe("DealIntel")
    expect(THEME.brandPrimary).toBe("#29B5E8")
    expect(THEME.brandDark).toBe("#11567F")
    expect(THEME.brandBg).toBe("#0A1428")
    expect(THEME.appSubtitle).toBe("Infrastructure Investments")
    expect(THEME.logoUrl).toBe("/icon.svg")
  })

  it("uses NEXT_PUBLIC_APP_NAME when set", async () => {
    process.env.NEXT_PUBLIC_APP_NAME = "AcmeDealIntel"
    const { THEME } = await import("@/theme.config")
    expect(THEME.appName).toBe("AcmeDealIntel")
  })

  it("uses NEXT_PUBLIC_BRAND_COLOR when set", async () => {
    process.env.NEXT_PUBLIC_BRAND_COLOR = "#FF0000"
    const { THEME } = await import("@/theme.config")
    expect(THEME.brandPrimary).toBe("#FF0000")
  })
})

describe("DB config", () => {
  beforeEach(() => { vi.resetModules() })
  afterEach(() => { delete process.env.DEAL_INTEL_DATABASE })

  it("defaults to DEAL_INTEL", async () => {
    const { DB } = await import("@/lib/db")
    expect(DB).toBe("DEAL_INTEL")
  })

  it("uses DEAL_INTEL_DATABASE env var when set", async () => {
    process.env.DEAL_INTEL_DATABASE = "CUSTOM_DB"
    const { DB } = await import("@/lib/db")
    expect(DB).toBe("CUSTOM_DB")
  })
})
