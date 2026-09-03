# DealIntel — Document Intelligence for Infrastructure Investments

AI-powered document intelligence platform for infrastructure PE portfolios. Ingests documents from source system (Vertafore), extracts structured data using Snowflake Cortex AI, and makes the entire corpus queryable through natural language search, Cortex Analyst structured analytics, and a Cortex Agent routing interface.

**Stack:** Next.js 16 (App Router) · TypeScript strict · Snowflake App Runtime (SPCS) · Cortex Search · Cortex Analyst · Cortex Agent

---

## Local Development

```bash
cd app/
npm install
npm run dev
```

The app reads Snowflake credentials automatically from your default [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials) connection in `~/.snowflake/config.toml`. No extra configuration needed if you already have `snow` CLI set up.

To use a specific named connection:
```bash
SNOWFLAKE_CONNECTION_NAME=myconn npm run dev
```

Or provide credentials directly:
```bash
SNOWFLAKE_ACCOUNT=myaccount \
SNOWFLAKE_ACCOUNT_URL=https://myaccount.snowflakecomputing.com \
SNOWFLAKE_USER=myuser \
SNOWFLAKE_PASSWORD=mypassword \
SNOWFLAKE_WAREHOUSE=DEAL_INTEL_QUERY_WH \
npm run dev
```

> **Note for Cortex Analyst + Cortex Agent:** The `/api/analyst` and `/api/agent` routes
> call Snowflake REST APIs that require a base URL. Set `SNOWFLAKE_HOST` (or `SNOWFLAKE_ACCOUNT_URL`)
> in your `.env.local`:
> ```
> SNOWFLAKE_HOST=https://your-account.snowflakecomputing.com
> ```
> Without this, `/api/analyst` returns 503 and `/api/agent` returns 500.
> In SPCS production, `SNOWFLAKE_HOST` is injected automatically.

See `.env.example` for the full list of configuration options.

---

## Deploy

Configure deployment variables in `../deploy.config`, then run:

```bash
../deploy.sh          # deploys infra + app + grants (recommended)
# or manually:
snow app deploy       # app only (requires infra already deployed)
```

Full deployment instructions: see [`../docs/DEPLOYMENT_GUIDE.md`](../docs/DEPLOYMENT_GUIDE.md).

---

## API Routes

| Route | Auth | Description |
|---|---|---|
| `GET /api/health` | None | Snowflake connection check |
| `GET /api/auth` | None | Current user role detection |
| `GET /api/filters` | requireUser | Dynamic folder/sector/doctype filter lists |
| `GET /api/search` | requireUser | Cortex Search (hybrid vector + keyword) |
| `POST /api/agent` | requireUser | Cortex Agent (deal_intelligence_agent) with RAG fallback |
| `POST /api/analyst` | requireUser | Cortex Analyst REST API → SQL + results |
| `GET /api/analytics` | requireUser | Document distribution charts |
| `GET /api/documents` | requireUser | Paginated document browser |
| `GET/POST/DELETE /api/saved` | requireUser | Saved searches CRUD |
| `POST/DELETE /api/bookmarks` | requireUser | Document bookmarks |
| `POST /api/feedback` | requireUser | Thumbs up/down feedback |
| `GET /api/admin` | requireAdmin | Admin actions (reprocess, approve, reject) |
| `GET/PUT /api/config` | requireAdmin | System config |
| `GET /api/quality` | requireAdmin | Quality metrics + pending corrections |
| `GET /api/registry` | requireAdmin | Ingestion registry |
| `GET /api/pipeline` | requireAdmin | Queue health metrics |
| `GET /api/tasks` | requireAdmin | Snowflake task status |
| `GET /api/users` | requireAdmin | User activity + role membership |
| `GET /api/cost` | requireAdmin | Credit cost by folder/stage |
| `GET/POST/PUT/DELETE /api/admin/classification-labels` | requireAdmin | Classification labels + categories CRUD |
| `GET/POST/PUT/DELETE /api/admin/lobs` | requireAdmin | Investment Sectors CRUD |
| `GET/POST /api/admin/extraction-test` | requireAdmin | Test Lab: list stages/files, run full pipeline |

---

## Key Concepts

- **`querySnowflake(sql, { callersRights: true })`** — import in any server component or route handler. Use `callersRights: true` on all data queries to enforce Snowflake row-level security per the calling user's grants.
- **`export const dynamic = "force-dynamic"`** — required on all pages/routes that query Snowflake. Prevents build-time rendering when the DB is unreachable.
- **`lib/api-utils.ts`** — `requireUser()`, `requireAdmin()`, `escSql()`, `clampInt()` helpers. Every data route calls `requireUser()` or `requireAdmin()` as its first statement.
- **Caller's rights** — SPCS injects `sf-context-current-user-token` per request. Routes that call `querySnowflake(..., { callersRights: true })` combine the service token + caller token so Snowflake evaluates queries with the caller's role, not the service identity.
- **Branding** — Controlled entirely via environment variables (no code changes needed):
  - `NEXT_PUBLIC_APP_NAME` — app title (default: `DealIntel`)
  - `NEXT_PUBLIC_BRAND_COLOR` — primary colour (default: `#29B5E8`)
  - `NEXT_PUBLIC_LOGO_URL` — logo image path (default: `/icon.svg`)
  - See `app/.env.example` and `PRODUCT_PLAN.md` Section 16 for the full list.
- **REST API routes** — `/api/agent` and `/api/analyst` call Snowflake REST APIs directly (not via the Node.js SDK). They use `getSnowflakeBaseUrl()` and `getRestApiAuthHeader()` / SPCS combined tokens from `lib/snowflake.ts`. Requires `SNOWFLAKE_HOST` in local dev.

---

## Testing

```bash
cd app/
npm test          # run all vitest unit tests
npm run build     # TypeScript strict mode check + build
```

14 test files in `app/__tests__/api/` covering all 19 API routes.
