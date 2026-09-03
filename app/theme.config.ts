/**
 * Theme configuration for white-label deployments.
 *
 * Clients set these environment variables to brand the app:
 *   NEXT_PUBLIC_APP_NAME      — application title
 *   NEXT_PUBLIC_APP_SUBTITLE  — subtitle shown in sidebar
 *   NEXT_PUBLIC_BRAND_COLOR   — primary color (buttons, links, highlights)
 *   NEXT_PUBLIC_BRAND_DARK    — dark accent (sidebar text, headings)
 *   NEXT_PUBLIC_BRAND_BG      — hero background / gradient start
 *   NEXT_PUBLIC_LOGO_URL      — path to logo image in /public
 *
 * All values fall back to DealIntel defaults when env vars are not set.
 */
export const THEME = {
  appName:      process.env.NEXT_PUBLIC_APP_NAME     ?? "DealIntel",
  appSubtitle:  process.env.NEXT_PUBLIC_APP_SUBTITLE ?? "Infrastructure Investments",
  brandPrimary: process.env.NEXT_PUBLIC_BRAND_COLOR  ?? "#C5A55A",
  brandDark:    process.env.NEXT_PUBLIC_BRAND_DARK   ?? "#1B2A4A",
  brandBg:      process.env.NEXT_PUBLIC_BRAND_BG     ?? "#0F1B2D",
  logoUrl:      process.env.NEXT_PUBLIC_LOGO_URL     ?? "/icon.svg",
} as const

export type Theme = typeof THEME
