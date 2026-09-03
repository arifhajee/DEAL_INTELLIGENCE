# DEAL_INTEL: Comprehensive Test Plan

## Overview

This test plan covers the complete Document Intelligence pipeline, from file ingestion through AI processing, search, analytics, and the Next.js frontend. Tests are organized into 6 suites covering different quality dimensions.

**Target environment:** `DEAL_INTEL` database on Snowflake  
**Roles:** `DEAL_INTEL_ADMIN` for setup, `DEAL_INTEL_USER`/`DEAL_INTEL_PIPELINE` for access tests  
**Warehouse:** `DEAL_INTEL_WH` (pipeline), `DEAL_INTEL_QUERY_WH` (queries)

---

## T1: Unit Tests — SQL Functions & Procedures

### T1.1 Ingestion Registry Deduplication

| Test ID | Scenario | Expected Result | SQL File |
|---|---|---|---|
| T1.1.1 | Insert new file never seen before | 1 row inserted, status=PENDING | test_dedup.sql |
| T1.1.2 | Re-run register with same unchanged file | 0 new rows, last_seen_at updated | test_dedup.sql |
| T1.1.3 | Re-run register with changed file (different size) | 1 new version row, version=2 | test_dedup.sql |
| T1.1.4 | FAILED file with attempts < 3 | Status reset to PENDING | test_dedup.sql |
| T1.1.5 | FAILED file with attempts ≥ 3 | Status set to ABANDONED | test_dedup.sql |
| T1.1.6 | Force reprocess COMPLETE file | New version row inserted | test_dedup.sql |
| T1.1.7 | PROCESSING file (in-flight lock) | No new row, no status change | test_dedup.sql |
| T1.1.8 | Bulk reprocess dry run | Returns rows with WOULD_REPROCESS, no inserts | test_dedup.sql |
| T1.1.9 | Bulk reprocess live run | New version rows inserted for matching docs | test_dedup.sql |
| T1.1.10 | Registry UNIQUE constraint | Second INSERT for same path+version fails | test_dedup.sql |

### T1.2 Pipeline Stored Procedures

| Test ID | Scenario | Expected Result |
|---|---|---|
| T1.2.1 | sp_parse_pending_documents — TIFF file | Uses OCR mode, produces raw_content |
| T1.2.2 | sp_parse_pending_documents — PDF file | Uses LAYOUT mode, page_count > 0 |
| T1.2.3 | sp_parse_pending_documents — corrupt file | Error logged, status=FAILED, pipeline continues |
| T1.2.4 | sp_classify_parsed_documents | primary_document_type not null |
| T1.2.5 | sp_classify_parsed_documents | confidence_score between 0 and 1 |
| T1.2.6 | sp_extract_document_attributes | extracted_attributes VARIANT is valid JSON |
| T1.2.7 | sp_extract_document_attributes | deal_code falls back to ir_deal_code |
| T1.2.8 | sp_emit_pipeline_metrics | Event row inserted in pipeline_events |
| T1.2.9 | sp_force_reprocess with invalid path | Returns ERROR: File not found |
| T1.2.10 | sp_reset_pipeline without CONFIRM | Returns ERROR: Pass CONFIRM_RESET |

### T1.3 Telemetry Views

| Test ID | View | Assertion |
|---|---|---|
| T1.3.1 | v_pipeline_health | Returns exactly 1 row |
| T1.3.2 | v_pipeline_health | SUM of all statuses = total_registered |
| T1.3.3 | v_ingestion_metrics | failure_rate_pct between 0 and 100 |
| T1.3.4 | v_cost_by_drawer | total_credits >= 0 |
| T1.3.5 | v_quality_metrics | avg_confidence between 0 and 1 |
| T1.3.6 | v_error_summary | Only rows with status=FAILED |

---

## T2: Integration Tests — Pipeline End-to-End

### T2.1 Full Pipeline by Format

For each supported format, trace a file through all 7 pipeline stages.

| Test ID | Format | Test Steps |
|---|---|---|
| T2.1.1 | PDF (digital) | Upload → register → parse (LAYOUT) → classify → extract → catalog → search |
| T2.1.2 | TIFF (scanned) | Upload → register → parse (OCR) → classify → extract → catalog → search |
| T2.1.3 | DOCX | Upload → register → parse (LAYOUT) → classify → extract → catalog → search |
| T2.1.4 | JPEG | Upload → register → parse (OCR) → classify → extract → catalog → search |
| T2.1.5 | PNG | Upload → register → parse (OCR) → classify → extract → catalog → search |
| T2.1.6 | HTML | Upload → register → parse (LAYOUT) → classify → extract → catalog → search |
| T2.1.7 | TXT | Upload → register → parse (LAYOUT) → classify → extract → catalog → search |

**For each format test, verify:**
- `ingestion_registry.ingestion_status = 'COMPLETE'`
- `parsed_documents.raw_content IS NOT NULL AND LENGTH > 0`
- `document_pages` rows exist
- `classified_documents.primary_document_type IS NOT NULL`
- `document_attributes.doc_summary IS NOT NULL`
- `document_catalog` row exists for the file
- File is retrievable via `SEARCH_PREVIEW`

### T2.2 Error Recovery

| Test ID | Scenario | Verification |
|---|---|---|
| T2.2.1 | Upload file with 0 bytes | status=FAILED, error logged, others unaffected |
| T2.2.2 | Upload oversized file (>100MB) | status=FAILED with AI error message |
| T2.2.3 | Upload non-deal content (recipe book) | Classified but with lower confidence |
| T2.2.4 | File removed from stage after registration | Pipeline handles missing file gracefully |

### T2.3 Deduplication Integration

| Test ID | Scenario | Verification |
|---|---|---|
| T2.3.1 | Same file uploaded twice (identical) | document_catalog shows 1 row, version=1 |
| T2.3.2 | Modified file re-uploaded | document_catalog shows latest version only |
| T2.3.3 | Previous version preserved in history tables | ingestion_registry has both versions |
| T2.3.4 | Force reprocess via admin | New version appears in catalog after next task run |

### T2.4 Metadata Sidecar Integration

| Test ID | Scenario | Verification |
|---|---|---|
| T2.4.1 | File with valid metadata sidecar | ir_file_id, ir_drawer populated correctly |
| T2.4.2 | File without metadata sidecar | ir_* fields are NULL, processing still completes |
| T2.4.3 | Sidecar UserKey1 matches AI-extracted policy # | classification_match = TRUE |
| T2.4.4 | Sidecar UserKey1 differs from AI-extracted # | Conflict flagged in extraction_overrides |

---

## T3: Search & Analytics Tests

### T3.1 Cortex Search — Relevance

Run each query against the sample data and verify top results.

| Test ID | Query | Expected Top Result |
|---|---|---|
| T3.1.1 | "D&O directors officers submission" | Acme Holdings D&O submission |
| T3.1.2 | "cyber data breach FNOL" | TechCorp Cyber FNOL |
| T3.1.3 | "coverage opinion prior knowledge exclusion E&O" | Johnson Advisory E&O coverage opinion |
| T3.1.4 | "facultative redeal certificate" | Acme Holdings redeal cert |
| T3.1.5 | "deals-made retroactive date directors" | D&O documents with retro dates |
| T3.1.6 | "self-insured retention SIR" | Documents with SIR language |
| T3.1.7 | "settlement agreement indemnity" | Settlement documents |
| T3.1.8 | "professional liability errors omissions" | E&O documents |
| T3.1.9 | "environmental remediation liability" | Environmental docs |
| T3.1.10 | "cyber incident response notification" | Cyber-related documents |

### T3.2 Filter Tests

| Test ID | Filter | Expected Behavior |
|---|---|---|
| T3.2.1 | ir_drawer = 'Deals' filter | Only Deals drawer documents returned |
| T3.2.2 | ir_drawer = 'Deal Sourcing' filter | Only Deal Sourcing documents returned |
| T3.2.3 | document_type = 'FNOL' filter | Only FNOL documents returned |
| T3.2.4 | line_of_business = 'D&O' filter | Only D&O documents returned |
| T3.2.5 | doc_status = 'open' filter | Only open status documents returned |
| T3.2.6 | Multiple filters combined | AND logic applied correctly |
| T3.2.7 | Filter with no matching documents | Empty results, no error |

### T3.3 Cortex Analyst — Analytics

| Test ID | Question | Expected SQL Pattern |
|---|---|---|
| T3.3.1 | "How many documents per drawer?" | GROUP BY ir_drawer, COUNT(*) |
| T3.3.2 | "Documents added this week" | WHERE upload_timestamp >= DATEADD('WEEK',-1,...) |
| T3.3.3 | "D&O policy count" | WHERE line_of_business = 'D&O' |
| T3.3.4 | "Average confidence by document type" | GROUP BY document_type, AVG(classification_confidence) |
| T3.3.5 | "Open deals with retro dates" | WHERE doc_status='open' AND retroactive_date IS NOT NULL |
| T3.3.6 | "Expiring policies next 90 days" | WHERE expiration_date BETWEEN ... |

### T3.4 Agent Routing Tests

Verify the Cortex Agent routes to the correct tool.

| Test ID | Question Type | Expected Tool |
|---|---|---|
| T3.4.1 | "Find the D&O submission for Acme" | SEARCH |
| T3.4.2 | "What does the coverage opinion say?" | SEARCH |
| T3.4.3 | "How many deals are open?" | ANALYST |
| T3.4.4 | "Total D&O reserves across the book" | ANALYST |
| T3.4.5 | "Which policies expire next quarter?" | ANALYST |
| T3.4.6 | "Find all FNOLs mentioning attorney" | SEARCH |
| T3.4.7 | "Compare E&O vs D&O document volumes" | ANALYST |
| T3.4.8 | "What exclusions are in the TechCorp policy?" | SEARCH |

---

## T4: Security Tests

### T4.1 Row-Level Security

| Test ID | Role | Access Level | Notes |
|---|---|---|---|
| T4.1.1 | DEAL_INTEL_USER | Own-entitlement rows only | Filtered by entitlements table |
| T4.1.2 | DEAL_INTEL_PIPELINE | Pipeline-managed objects | Service role for task execution |
| T4.1.3 | DEAL_INTEL_ADMIN | All rows | Full access, no row filtering |

```sql
-- Example test for T4.1.3
USE ROLE DEAL_INTEL_ADMIN;
SELECT DISTINCT ir_drawer FROM DEAL_INTEL.APP.v_document_catalog;
-- Expected: All drawers visible (no row-level filtering for admin)
```

### T4.2 Admin Page Gating

| Test ID | Role | Expected Result |
|---|---|---|
| T4.2.1 | DEAL_INTEL_USER accessing admin table | INSUFFICIENT_PRIVILEGES error |
| T4.2.2 | DEAL_INTEL_USER calling sp_reset_pipeline | INSUFFICIENT_PRIVILEGES error |
| T4.2.3 | DEAL_INTEL_USER calling sp_bulk_reprocess | INSUFFICIENT_PRIVILEGES error |

### T4.3 PII Masking

| Test ID | Field | Role | Expected |
|---|---|---|---|
| T4.3.1 | SSN patterns in extracted text | DEAL_INTEL_USER | Masked |
| T4.3.2 | SSN patterns in extracted text | DEAL_INTEL_PIPELINE | Masked |
| T4.3.3 | SSN patterns in extracted text | DEAL_INTEL_ADMIN | Visible |

---

## T5: Performance Tests

### T5.1 Pipeline Throughput

| Test ID | Scenario | Target |
|---|---|---|
| T5.1.1 | Process 100 sample PDFs | Complete in < 15 minutes |
| T5.1.2 | Process 50 TIFFs (3 pages each) | Complete in < 10 minutes |
| T5.1.3 | Register 1,000 new files | sp_register_new_files completes in < 60s |
| T5.1.4 | Dynamic Table full refresh | Completes in < 5 minutes |

### T5.2 Query Performance

| Test ID | Query | Target Latency |
|---|---|---|
| T5.2.1 | Cortex Search — simple text query | p50 < 2s, p95 < 5s |
| T5.2.2 | Cortex Search — with 3 filters | p50 < 3s, p95 < 7s |
| T5.2.3 | v_pipeline_health query | < 2s |
| T5.2.4 | v_document_catalog full scan (1K docs) | < 5s |
| T5.2.5 | Agent Q&A round-trip | p50 < 8s, p95 < 15s |

### T5.3 Concurrency

| Test ID | Scenario | Target |
|---|---|---|
| T5.3.1 | 10 concurrent search queries | All complete, no errors |
| T5.3.2 | 50 concurrent user sessions (Next.js app) | App remains responsive, no 503s |
| T5.3.3 | Pipeline running + user queries | No interference between warehouses |

---

## T6: Frontend Tests (Next.js App)

These tests cover the Next.js/React frontend deployed via Snowflake App Runtime (SPCS).
Unit and component tests use `vitest`. E2E tests use Playwright against the deployed app URL.

### T6.1 Page Load Tests

| Test ID | Page | Expectation | Test Type |
|---|---|---|---|
| T6.1.1 | `/` — Dashboard | Loads in < 5s, pipeline KPIs visible, no 404 | Playwright |
| T6.1.2 | `/search` — Search | Loads in < 3s, search bar auto-focused | Playwright |
| T6.1.3 | `/analytics` — Analytics | Charts render in < 8s, no blank area | Playwright |
| T6.1.4 | `/documents` — Browser | Table loads first 50 rows in < 5s | Playwright |
| T6.1.5 | `/admin/pipeline` — Pipeline | Task status visible for admin users | Playwright |
| T6.1.6 | `/admin/pipeline` as non-admin | Admin lock screen displayed | Playwright |

### T6.2 Search Flow

| Test ID | Action | Expected Outcome | Test Type |
|---|---|---|---|
| T6.2.1 | Type query → click Search | Results appear with doc type badges | Playwright |
| T6.2.2 | Click 👍 on result | `POST /api/feedback` called, visual confirmation | vitest + Playwright |
| T6.2.3 | Click 👎 on result | `POST /api/feedback` called, visual confirmation | vitest + Playwright |
| T6.2.4 | Expand result detail | Full text visible, metadata shown | Playwright |
| T6.2.5 | Click 🔖 Bookmark | `POST /api/bookmarks` called, button turns filled | vitest + Playwright |
| T6.2.6 | Click Save Search | Save dialog appears, `POST /api/saved` called | vitest + Playwright |
| T6.2.7 | Search with no results | Empty state with "No results found" and guidance | Playwright |

### T6.3 Chat Flow

| Test ID | Action | Expected Outcome | Test Type |
|---|---|---|---|
| T6.3.1 | Type question and send | Response appears with tool badge | Playwright |
| T6.3.2 | Follow-up question | Context maintained from prior turn | Playwright |
| T6.3.3 | Click quick question | Pre-populates input and sends | Playwright |
| T6.3.4 | Click "New conversation" | Chat thread cleared | Playwright |
| T6.3.5 | Analytical question | Tool badge shows "Analytics" | Playwright |

### T6.4 Admin Tests

| Test ID | Action | Expected Outcome | Test Type |
|---|---|---|---|
| T6.4.1 | Non-admin accesses `/admin/pipeline` | AdminOnly lock screen shown | Playwright |
| T6.4.2 | Admin views pipeline health | Queue KPIs and task status table shown | Playwright |
| T6.4.3 | Admin force-reprocesses file | `POST /api/admin` called, toast shown | vitest + Playwright |
| T6.4.4 | Admin approves override | `POST /api/admin` with approve_override | vitest |
| T6.4.5 | Admin saves config change | `PUT /api/config` called, checkmark shown | vitest + Playwright |

### T6.5 Unit Tests (vitest)

Run with `cd app && npm test`:

| Test File | What it tests |
|---|---|
| `__tests__/theme.test.ts` | THEME defaults, env var overrides, DB constant |
| `__tests__/api/health.test.ts` | Health endpoint 200/503 |
| `__tests__/api/core-routes.test.ts` | Filters, auth role detection, admin actions |
| `__tests__/api/search.test.ts` | Search blank/filter/limit/error paths |
| `__tests__/api/agent.test.ts` | Cortex Agent call, RAG fallback paths, base URL null → fallback, agent 503 → fallback |
| `__tests__/api/analyst.test.ts` | Cortex Analyst REST: apostrophe passthrough (C-1 regression), SQL+results shape, local dev auth |
| `__tests__/api/documents.test.ts` | Pagination, filter, limit cap |
| `__tests__/api/saved.test.ts` | CRUD validation for saved searches |
| `__tests__/api/analytics.test.ts` | Chart array shape, requireUser guard |
| `__tests__/api/feedback.test.ts` | feedbackType allowlist, SQL injection prevention, missing filePath |
| `__tests__/api/bookmarks.test.ts` | MERGE upsert, note clearing (null vs preserve), DELETE validation |
| `__tests__/api/admin-routes.test.ts` | Cost KPI shape, quality metrics/irMatchPct, error paths |
| `__tests__/api/admin-pages.test.ts` | Config GET/PUT, pipeline health, tasks graceful fallback, users+roleSummary, registry pagination |

---

## Test Execution Instructions

### Setup

```sql
-- Run as DEAL_INTEL_ADMIN before executing tests
USE ROLE DEAL_INTEL_ADMIN;
USE WAREHOUSE DEAL_INTEL_WH;

-- Ensure sample data is loaded
-- Run sql/07_sample_data.sql if not already done
```

### Running SQL Tests

```bash
# Execute each test file
snow sql -f tests/sql/test_dedup.sql
snow sql -f tests/sql/test_pipeline.sql
snow sql -f tests/sql/test_telemetry.sql
snow sql -f tests/sql/test_security.sql
```

### Expected Outcomes

All SQL tests produce a result with columns `test_id`, `test_name`, `status` (PASS/FAIL), and `details`. A passing test suite shows all PASS rows.

### Performance Benchmarks

Run performance tests using:
```sql
-- T5.2.1: Search latency
SET start_ts = CURRENT_TIMESTAMP();
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('DEAL_INTEL.PUBLIC.deal_search_svc','{"query":"cyber claim","columns":["file_path"],"limit":10}'))['results'];
SELECT DATEDIFF('MILLISECOND', $start_ts, CURRENT_TIMESTAMP()) AS latency_ms;
```
