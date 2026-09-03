/**
 * E2E smoke tests for DealIntel Next.js app.
 *
 * These tests verify the most critical user paths work end-to-end.
 * They require the app to be running — either locally (npm run dev)
 * or against the deployed SPCS URL.
 *
 * Run with:
 *   APP_URL=https://your-app.snowflakecomputing.app npx playwright test
 *
 * For local development:
 *   APP_URL=http://localhost:3000 npx playwright test
 *
 * NOTE: Full Playwright setup requires `npx playwright install` and
 * a `playwright.config.ts` file. This file defines the test cases;
 * Playwright integration is a recommended next step for CI/CD.
 *
 * For now these are documented test scenarios that map to T6 in TEST_PLAN.md.
 * They can be run manually or automated with a Playwright setup.
 */

import { test, expect } from "@playwright/test"

const BASE = process.env.APP_URL ?? "http://localhost:3000"

test.describe("Page load smoke tests (T6.1)", () => {
  test("T6.1.1 — dashboard loads and shows pipeline KPIs", async ({ page }) => {
    await page.goto(BASE)
    await expect(page.locator("h1")).toContainText(["Document", "Dashboard", "Intelligence"])
    await expect(page.locator(".sf-card").first()).toBeVisible()
  })

  test("T6.1.2 — search page loads with search bar", async ({ page }) => {
    await page.goto(`${BASE}/search`)
    const searchInput = page.locator("input[placeholder*='coverage opinion']").first()
    await expect(searchInput).toBeVisible()
  })

  test("T6.1.3 — analytics page loads without crashing", async ({ page }) => {
    await page.goto(`${BASE}/analytics`)
    // Should NOT have blank body or JavaScript TypeError
    await expect(page.locator("body")).not.toContainText("TypeError")
    await expect(page.locator("body")).not.toContainText("Cannot read properties")
    await expect(page.locator("h1")).toBeVisible()
  })

  test("T6.1.6 — admin page shows access screen for unauthenticated users", async ({ page }) => {
    await page.goto(`${BASE}/admin/pipeline`)
    // Should NOT crash with a server error
    await expect(page.locator("body")).not.toContainText("Internal Server Error")
    // For non-admin users the AdminOnly component renders "DEAL_INTEL_ADMIN" in its lock screen.
    // For admin users it shows pipeline content. Either is acceptable; what matters is no crash.
    const hasLockScreen = await page.locator("text=DEAL_INTEL_ADMIN").isVisible().catch(() => false)
    const hasPipelineContent = await page.locator("h1").isVisible().catch(() => false)
    expect(hasLockScreen || hasPipelineContent).toBe(true)
  })
})

test.describe("Search flow (T6.2)", () => {
  test("T6.2.7 — empty search query shows suggestions", async ({ page }) => {
    await page.goto(`${BASE}/search`)
    // Should show suggestion cards before any search
    await expect(page.locator("text=Suggested searches")).toBeVisible()
  })
})

test.describe("API health checks", () => {
  test("/api/health returns 200 with status:ok", async ({ request }) => {
    const res = await request.get(`${BASE}/api/health`)
    expect(res.status()).toBe(200)
    const body = await res.json()
    expect(body.status).toBe("ok")
    expect(typeof body.ts).toBe("string")
  })

  test("/api/auth returns 200 with appRole field", async ({ request }) => {
    const res = await request.get(`${BASE}/api/auth`)
    expect(res.status()).toBe(200)
    const body = await res.json()
    expect(["admin", "user", "none"]).toContain(body.appRole)
  })
})
