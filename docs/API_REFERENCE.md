# DEAL_INTEL: API Reference

## Stored Procedures

### `sp_register_new_files()`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Scans both stages, registers new files, resets retryable failures, promotes abandoned failures, creates new versions for changed files.  
**Called by:** `task_01_register_files` (every 15 minutes)

```sql
CALL DEAL_INTEL.DATA.sp_register_new_files();
-- Returns: TABLE of pending documents
```

---

### `sp_force_reprocess(p_file_path, p_reason)`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Forces a document to be re-parsed, re-classified, and re-extracted regardless of its current status.

| Parameter | Type | Required | Description |
|---|---|---|---|
| p_file_path | VARCHAR | Yes | File path as stored in ingestion_registry |
| p_reason | VARCHAR | No | Human-readable reason for audit trail |

```sql
CALL DEAL_INTEL.DATA.sp_force_reprocess(
    'documents/my-document.pdf',
    'Coverage form was misclassified'
);
-- Returns: 'OK: File queued for reprocessing as version N' or 'ERROR: ...'
```

---

### `sp_bulk_reprocess(p_folder, p_file_format, p_from_date, p_to_date, p_dry_run)`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Bulk-queues COMPLETE documents for reprocessing based on filters.

| Parameter | Type | Default | Description |
|---|---|---|---|
| p_folder | VARCHAR | NULL | Filter by source_folder (NULL = all folders) |
| p_file_format | VARCHAR | NULL | Filter by file_format (NULL = all formats) |
| p_from_date | TIMESTAMP_NTZ | NULL | Filter by first_seen_at >= from_date |
| p_to_date | TIMESTAMP_NTZ | NULL | Filter by first_seen_at <= to_date |
| p_dry_run | BOOLEAN | TRUE | If TRUE, shows what would be reprocessed without doing it |

```sql
-- Preview which Deals TIFFs from 2024 would be reprocessed
CALL DEAL_INTEL.DATA.sp_bulk_reprocess(
    'Deals', 'TIFF',
    '2024-01-01'::TIMESTAMP_NTZ,
    '2024-12-31'::TIMESTAMP_NTZ,
    TRUE
);

-- Execute
CALL DEAL_INTEL.DATA.sp_bulk_reprocess('Deals', 'TIFF', NULL, NULL, FALSE);
```

---

### `sp_parse_pending_documents()`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Runs AI_PARSE_DOCUMENT on all documents in PROCESSING state. Called by `task_02_parse_documents`.

---

### `sp_classify_parsed_documents()`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Runs AI_CLASSIFY on parsed documents. Called by `task_03_classify_documents`.

---

### `sp_extract_document_attributes()`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Runs AI_EXTRACT on classified documents and marks registry as COMPLETE. Called by `task_04_extract_attributes`.

---

### `sp_emit_pipeline_metrics()`

**Schema:** `DEAL_INTEL.DATA`  
**Purpose:** Emits telemetry summary event and checks alert thresholds. Called by `task_05_emit_metrics`.

---

### `sp_approve_override(p_override_id)`

**Schema:** `DEAL_INTEL.ADMIN`  
**Purpose:** Approves a pending attribute correction, making it eligible for application in the next Dynamic Table refresh.

```sql
CALL DEAL_INTEL.ADMIN.sp_approve_override('uuid-of-override');
-- Returns: 'OK: Override approved...' or 'ERROR: ...'
```

---

### `sp_get_dashboard_stats()`

**Schema:** `DEAL_INTEL.ADMIN`  
**Purpose:** Returns key admin dashboard metrics with status indicators (OK/WARNING/CRITICAL).

```sql
CALL DEAL_INTEL.ADMIN.sp_get_dashboard_stats();
-- Returns: TABLE(metric VARCHAR, value VARCHAR, status VARCHAR)
```

---

### `sp_reset_pipeline(p_confirm)`

**Schema:** `DEAL_INTEL.ADMIN`  
**Purpose:** Emergency reset — moves all PROCESSING documents back to PENDING.

```sql
CALL DEAL_INTEL.ADMIN.sp_reset_pipeline('CONFIRM_RESET');
-- Must pass exact string 'CONFIRM_RESET' to prevent accidental execution
```

---

## Cortex Services

### `deal_search_svc` (Cortex Search)

Document-level semantic search with structured attribute filters.

**REST API endpoint:**
```
https://<account>.snowflakecomputing.com/api/v2/databases/DEAL_INTEL/schemas/SERVICES/cortex-search-services/deal_search_svc:query
```

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| query | string | Natural language search text |
| columns | array | Columns to return |
| filter | object | Cortex Search filter object |
| limit | integer | Max results (default 10, max 1000) |

**Filterable columns:** `document_type`, `doc_status`, `source_folder`, `line_of_business`, `deal_stage`, `ir_deal_code`, `ir_fund_name`, `file_format`, `target_company`

**SQL example:**
```sql
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'DEAL_INTEL.SERVICES.deal_search_svc',
    '{
        "query": "investment memo prior knowledge exclusion",
        "columns": ["file_path","document_type","target_company","doc_summary"],
        "filter": {"@eq": {"source_folder": "Deals"}},
        "limit": 10
    }'
))['results'] AS results;
```

---

### `deal_page_search_svc` (Cortex Search)

Page-level search for granular content retrieval within multi-page documents.

**Filterable:** `source_folder`, `ir_deal_code`, `ir_fund_name`, `file_path`

---

### `deal_analytics_sv` (Semantic View — Cortex Analyst)

Natural language to SQL for portfolio analytics. See `DATA_DICTIONARY.md` for full column list.

**Usage in Next.js app** (via `/api/analyst` route):
```typescript
const res = await fetch("/api/analyst", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    question: "How many Digital Infrastructure deals are open by month this year?",
    history: []
  }),
})
const { answer, sql, results, requestId } = await res.json()
// answer:    string   — prose explanation from Cortex Analyst
// sql:       string | null — generated SQL statement
// results:   object[] — executed query results (up to 100 rows)
// requestId: string | null — Cortex Analyst request ID for debugging
```

The `/api/analyst` route calls the Cortex Analyst REST API
(`POST /api/v2/cortex/analyst/message`) against `deal_analytics_sv`,
then executes the generated SQL against Snowflake and returns actual data rows.
The analytics page NL box renders the prose answer, the SQL (expandable),
and a results table.

**Direct SQL (for Snowflake SQL clients):**
```sql
-- Cortex Analyst is also available via Snowflake Intelligence (CoWork)
-- or via direct API call — no intermediate SQL wrapper needed
SELECT SNOWFLAKE.CORTEX.ANALYST.RUN(
    'DEAL_INTEL.SERVICES.deal_analytics_sv',
    'How many Digital Infrastructure deals are open by month this year?'
);
```

---

### `deal_intelligence_agent` (Cortex Agent)

Full routing agent combining document search, page-level search, and Cortex Analyst.
Autonomously routes between its three tools based on question intent:
- **`doc_search`** — Cortex Search on full documents (find, retrieve, what does X say)
- **`page_search`** — Cortex Search on individual pages (specific clause language)
- **`doc_analytics`** — Cortex Analyst (how many, count, breakdown, trend)

**Usage in Next.js app** (via `/api/agent` route):
```typescript
const res = await fetch("/api/agent", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    question: "What exclusions apply to our Digital Infrastructure investments?",
    history: []
  }),
})
// Response is SSE stream (Content-Type: text/event-stream)
const reader = res.body.getReader()
// Each SSE event is JSON with one of these shapes:
// Text chunk:   { delta: string, toolUsed: string, done: boolean }
// Status:       { status: string, toolUsed: string, done: false }
// Chart data:   { resultSet: { columns: string[], rows: any[][], title?: string }, toolUsed: string, done: false }
// Final event has done: true
```

The `/api/agent` route calls the Cortex Agent REST API
(`POST /api/v2/cortex/agent:run`) with SSE streaming. Authentication uses a
combined OAuth token (`serviceToken.callerToken`) for SPCS caller identity.

**Environment requirements:**
- `SNOWFLAKE_HOST` env var must be set (available only in SPCS)
- Returns HTTP 500 if not running in an SPCS environment

The agent is also available via **Snowflake Intelligence (CoWork)** for direct
natural language access without any API calls.

---

## Telemetry Views

### `v_pipeline_health`

Current queue state snapshot. One row total.

```sql
SELECT * FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;
-- Columns: pending_count, processing_count, complete_count, failed_count,
--          abandoned_count, skipped_count, total_registered,
--          last_completed_at, oldest_pending_at, max_queue_age_minutes
```

### `v_ingestion_metrics`

Daily throughput and failure rates by source folder and format.

### `v_cost_by_folder`

Credit consumption by day, source folder, and pipeline stage.

### `v_search_analytics`

Query patterns, latency percentiles, and feedback rates.

### `v_quality_metrics`

AI classification confidence distribution by document type.

### `v_error_summary`

Error patterns grouped by stage and message.

### `v_agent_audit_log` (APP schema)

Anonymized audit log of all agent/CoWork queries (response text truncated, no PII).

---

## Next.js App API Routes

All routes are deployed as Next.js App Router handlers in `app/app/api/`.
Routes marked **requireUser** accept any DEAL_INTEL role (user, admin, or pipeline).
Routes marked **requireAdmin** require DEAL_INTEL_ADMIN specifically.

| Route | Method | Auth | Description |
|---|---|---|---|
| `/api/health` | GET | None | Snowflake connectivity check. Returns `{ status, ts }` on success, 503 on failure. No database name or error details exposed. |
| `/api/auth` | GET | None | Detect current user's DEAL_INTEL app role (`admin`, `user`, or `none`). Used by client-side role context. |
| `/api/filters` | GET | requireUser | Dynamic lists for filter dropdowns: source folders, sectors, document types, statuses, file formats, and feature flags. |
| `/api/search` | GET | requireUser | Cortex Search hybrid retrieval. Params: `q`, `folder`, `lob`, `docType`, `status`, `format`, `limit` (max 50). Returns array of results with AI-extracted fields. |
| `/api/agent` | POST | requireUser | Cortex Agent (`deal_intelligence_agent`) SSE streaming endpoint. Requires SPCS environment (`SNOWFLAKE_HOST`). Body: `{ question, history[] }`. Returns `text/event-stream` with events: `{ delta, toolUsed, done }`, `{ status, toolUsed, done }`, `{ resultSet, toolUsed, done }`. |
| `/api/analyst` | POST | requireUser | Cortex Analyst REST API against `deal_analytics_sv`. Body: `{ question, history[] }`. Returns `{ answer, sql, results[], requestId, warnings[] }`. |
| `/api/analytics` | GET | requireUser | Document distribution chart data (byType, byLob, byDrawer, byStatus). |
| `/api/documents` | GET | requireUser | Paginated document catalog browser. Params: `folder`, `docType`, `lob`, `status`, `review`, `limit` (max 200), `offset`. Returns `{ rows[], total, limit, offset }`. |
| `/api/saved` | GET/POST/DELETE | requireUser | Saved searches CRUD. POST body: `{ name, queryText, filtersJson }`. DELETE param: `?id=`. |
| `/api/bookmarks` | POST/DELETE | requireUser | Document bookmarks. POST body: `{ filePath, irFileId?, documentType?, insuredName?, note? }`. DELETE param: `?file_path=`. |
| `/api/feedback` | POST | requireUser | Thumbs up/down feedback on search results. Body: `{ filePath, feedbackType, queryText?, documentType? }`. `feedbackType` must be `thumbs_up` or `thumbs_down`. |
| `/api/admin` | POST | requireAdmin | Admin actions: `force_reprocess`, `approve_override`, `reject_override`, `submit_correction`. |
| `/api/config` | GET/PUT | requireAdmin | System config key/value store. PUT body: `{ key, value }`. |
| `/api/quality` | GET | requireAdmin | Quality metrics (`avgConfidence`, `lowConfPct`, `irMatchPct`) + pending corrections + feedback log. |
| `/api/registry` | GET | requireAdmin | Paginated ingestion registry. Params: `status`, `folder`, `limit` (max 200), `offset`. QUALIFY deduplication on `file_path`. |
| `/api/pipeline` | GET | requireAdmin | Pipeline queue health snapshot from `v_pipeline_health`. |
| `/api/tasks` | GET | requireAdmin | Snowflake task status via `SHOW TASKS` + task run history. |
| `/api/users` | GET | requireAdmin | User activity from `agent_audit_log` (last 30 days) + role membership from `SHOW GRANTS OF ROLE`. |
| `/api/cost` | GET | requireAdmin | Credit consumption: by source folder (last 30 days) + by pipeline stage (last 7 days from `pipeline_events`). KPIs: `total7d`, `avgDaily` (total/30), `projectedMonthly`. |
| `/api/admin/classification-labels` | GET/POST/PUT/DELETE | requireAdmin | Classification labels CRUD: list, create, toggle active, rename/delete categories. |
| `/api/admin/lobs` | GET/POST/PUT/DELETE | requireAdmin | Investment Sectors CRUD: list, create, toggle active, update details, delete. |
| `/api/models` | GET | requireUser | Available Cortex LLM and extraction models. Queries `SHOW CORTEX BASE MODELS`, filters to GA/PUPR status, returns `{ cortex_model: string[], extraction_model: string[] }`. |
| `/api/documents/download` | GET | requireUser | Generate presigned URL for a document on stage. Params: `file_path` (required), `stage_name` (optional, defaults to `@DEAL_INTEL.DATA.deal_documents_stage`). Enforces `canDownload` entitlement and sector access. Logs download event to pipeline_events. Returns `{ url, file_path, stage_name }` or 404 if file not found. |

---

## New Routes Added (Phases 3–6)

### Document Detail Routes

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/documents/detail` | GET | requireUser | Full document detail. Param: `id` (base64url-encoded file_path). Returns `{ document, pendingCorrections[] }`. Applies sector entitlement filter. |
| `/api/documents/history` | GET | requireUser | Processing version history. Param: `id`. Returns `{ history[] }` with version, status, timestamps, errors. |
| `/api/documents/related` | GET | requireUser | Related documents by insured/policy/claim. Param: `id`. Returns `{ related[] }`. Applies sector filter. |
| `/api/documents/export` | GET | requireUser | Export filtered document catalog as CSV. Params: `format`, `lob`, `doc_type`, `status`. Respects `canDownload` entitlement. |

**URL scheme:** Document `id` params are base64url-encoded file paths (+ → -, / → _, = stripped). Encode: `btoa(filePath).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"")`. Decode: reverse. This is required because Snowflake App Runtime (SAR) cannot deploy Next.js `[param]` bracket directories.

### Review Queue

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/review` | GET | requireUser | Entitlement-scoped review queue. Params: `status` (pending/approved/skipped/all), `limit`, `offset`. Filters by user's `lobAccess` + `docTypeAccess`. Returns `{ rows[], total }`. |
| `/api/review?action=count` | GET | requireUser | Badge count endpoint. Returns `{ pending, approved, skipped }` scoped to user entitlements. |
| `/api/review` | POST | requireUser | Review action. Body: `{ filePath, action: "approve"\|"skip" }`. Inserts/updates `extraction_overrides` with `field_name='__review_status__'`. |

### Extraction Test Lab

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/admin/extraction-test?action=list_stages` | GET | requireUser | Returns configured ingestion stages from `ADMIN.ingestion_stages`. |
| `/api/admin/extraction-test?action=list_files&stage=<name>` | GET | requireUser | Lists files on a stage via `LIST @stage_name`. Filters to supported document extensions. |
| `/api/admin/extraction-test` | POST | requireAdmin | On-demand extraction. Body: `{ filePath, stageName, mode: "full"\|"single_attr" }` or `{ files[], stageName }` for batch. Full pipeline: Parse → Classify Document Type → Detect sector (reads active sectors from `lines_of_business` table) → Resolve Schema (COMMON + CATEGORY + sector_SPECIFIC tiers) → Extract. Returns `{ ok, results: { raw_text, classification, lob, extraction, fieldTiers } }`. |

### Classification Labels CRUD

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/admin/classification-labels` | GET | requireAdmin | List all classification labels ordered by category and sort_order. Returns `{ labels[] }`. |
| `/api/admin/classification-labels` | POST | requireAdmin | Create label. Body: `{ label, category }`. |
| `/api/admin/classification-labels` | PUT | requireAdmin | Toggle active (`{ label, isActive }`), rename category (`{ action: "rename_category", oldName, newName }`), or delete category (`{ action: "delete_category", category }`). |
| `/api/admin/classification-labels?label=<name>` | DELETE | requireAdmin | Delete a single label by name. |

### Investment Sectors CRUD

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/admin/lobs` | GET | requireAdmin | List all sectors ordered by sort_order. Returns `{ lobs[] }` with `lob_code`, `lob_name`, `description`, `is_active`, `sort_order`. |
| `/api/admin/lobs` | POST | requireAdmin | Create sector. Body: `{ lobCode, lobName, description? }`. Auto-assigns next sort_order. Returns 409 if code exists. |
| `/api/admin/lobs` | PUT | requireAdmin | Toggle active (`{ lobCode, isActive }`) or update details (`{ lobCode, lobName, description }`). |
| `/api/admin/lobs?lob_code=<code>` | DELETE | requireAdmin | Delete a sector by code. |

### Routes Updated in Phases 3–6

| Route | Change |
|-------|--------|
| `/api/health` | Now requires DEAL_INTEL role (was unauthenticated — security fix) |
| `/api/documents/download` | Enforces `canDownload` + sector access. Logs download event to `TELEMETRY.pipeline_events`. |
| `/api/documents/proxy` | Enforces `canDownload` + sector access. Logs view event to `TELEMETRY.pipeline_events`. |
| `/api/search` | New `scope` param (base64url file_path) switches to `deal_page_search_svc` for intra-document search. |
| `/api/agent` | Now uses Cortex Agent REST API with SSE streaming. Requires SPCS (`SNOWFLAKE_HOST`). Citations formatted as `[filename, p.N]`. |
| `/api/admin/pipeline` | New `action=preview_reprocess` returns match count without triggering reprocess. |
| `/api/bookmarks` | Added GET handler to list current user's bookmarks from `ADMIN.document_bookmarks`. |

---

## Entitlements Architecture (Multi-Role)

### Overview

Access control is role-based with multi-role support. Users get access exclusively through role membership — no custom/direct entitlements. A user can be assigned multiple roles; effective access = union of all assigned roles' arrays.

### Tables

| Table | Purpose |
|-------|---------|
| `ADMIN.entitlement_roles` | Named role templates with `menu_access`, `lob_access`, `doc_type_access`, `can_download` arrays |
| `ADMIN.user_entitlements` | User rows with `is_active` flag (app role is derived from entitlement roles' menu_access) |
| `ADMIN.user_role_assignments` | Junction table: `(user_name, role_id)` — multiple roles per user |
| `ADMIN.lines_of_business` | Master sector configuration table — drives AI_CLASSIFY sector detection dynamically. Managed via Admin → Investment Sectors |

### Resolution Logic (`app/lib/entitlements.ts`)

1. Load all active role assignments for the user from `user_role_assignments`
2. For each role, load `menu_access`, `lob_access`, `doc_type_access`, `can_download`
3. UNION all arrays — effective access = union of all assigned roles
4. If ANY array contains `"*"` (wildcard), that dimension grants full access
5. `canDownload = true` if ANY assigned role allows downloads
6. `appRole` is derived: if any `menuAccess` entry starts with `admin:`, the user is `admin`; otherwise `user`

### SQL Helper Functions

```typescript
// Apply to any SQL query to enforce sector entitlements
lobFilter(entitlements, "line_of_business")
// → AND line_of_business IN ('DO','EO','CY') | (empty string if wildcard)

docTypeFilter(entitlements, "doc_type_category")  
// → AND doc_type_category IN ('IC Presentation','DD Report') | (empty string if wildcard)
```

Both helpers return an empty string when the user has wildcard access, so they can be unconditionally appended to WHERE clauses.

### Sidebar Reactivity

After an admin modifies role assignments, the sidebar menu updates without a page reload:
- `RoleProvider` exposes `refreshAuth()` via `useRole()` hook
- The user management page calls `refreshAuth()` after saving
- Re-fetches `/api/auth`, which re-evaluates entitlements and updates the sidebar

---

*Last updated: August 2026 — Phases 3–9 complete, plus CRUD labels/sectors, Test Lab pins, dynamic sector detection*
