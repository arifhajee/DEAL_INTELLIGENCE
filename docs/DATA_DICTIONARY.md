# DEAL_INTEL: Data Dictionary

Complete schema reference for all DEAL_INTEL tables, columns, and relationships.

## Database: DEAL_INTEL

---

## Quick Lookup: Common Columns by Name

These column names appear across multiple tables. Use the table below to verify which table(s) contain the column you need.

| Column | Tables |
|--------|--------|
| `FILE_PATH` | ingestion_registry, parsed_documents, classified_documents, document_attributes, document_catalog, document_pages, extraction_overrides, pipeline_events, document_bookmarks, search_feedback |
| `PROCESSING_VERSION` | ingestion_registry, parsed_documents, classified_documents, document_attributes, document_catalog, extraction_overrides |
| `SOURCE_FOLDER` | ingestion_registry, classified_documents, document_catalog, document_pages, pipeline_events |
| `IR_FILE_ID` | ingestion_registry, document_catalog, document_pages, pipeline_events |
| `INSURED_NAME` | document_attributes, document_catalog, document_bookmarks |
| `LINE_OF_BUSINESS` | document_attributes, document_catalog |
| `INGESTION_STATUS` | ingestion_registry, document_catalog |
| `CREATED_AT` | document_bookmarks, entitlement_roles, lines_of_business, user_entitlements, user_role_assignments, ingestion_stages, parsed_documents, document_pages |
| `USER_NAME` | user_entitlements, user_role_assignments, document_bookmarks, saved_searches, search_feedback, user_preferences, agent_audit_log, pipeline_events |
| `DOCUMENT_TYPE` | document_catalog, extraction_schemas, document_bookmarks |

### Columns That Do NOT Exist (Common Mistakes)

| Attempted Column | Fix |
|-----------------|-----|
| `document_catalog.FILE_NAME` | Does not exist. Derive from `FILE_PATH`: `SPLIT_PART(file_path, '/', -1)` |
| `extraction_overrides.CREATED_AT` | Use `SUBMITTED_AT` instead |
| `classified_documents.LINE_OF_BUSINESS` | Only on `document_attributes` and `document_catalog` |
| `classified_documents.INSURED_NAME` | Only on `document_attributes` and `document_catalog` |
| `user_entitlements.ROLE_NAME` | Only on `entitlement_roles`. JOIN via `user_role_assignments.role_id` |

---

## Schema: DATA (Pipeline Tables)

### `ingestion_registry`

Master registry of every file ever seen by the pipeline. Single source of truth for deduplication and processing state.

| Column | Type | Nullable | Description |
|---|---|---|---|
| registry_id | VARCHAR | NOT NULL (PK) | UUID — unique row identifier |
| file_path | VARCHAR | NOT NULL | Relative path within the stage (e.g., `documents/my-file.pdf`) |
| stage_name | VARCHAR | NOT NULL | Fully-qualified stage name |
| file_format | VARCHAR | NOT NULL | Uppercase file extension: TIFF, PDF, DOCX, JPEG, PNG, HTML, TXT |
| file_size_bytes | BIGINT | YES | File size in bytes from stage DIRECTORY() |
| file_hash | VARCHAR | YES | SHA2(256) of file bytes for change detection (set on parse) |
| ir_file_id | VARCHAR | YES | source system FileID (from metadata sidecar) |
| source_folder | VARCHAR | YES | Source folder / organizational grouping: Deals, Deal Sourcing, Redeal, etc. |
| ir_document_type | VARCHAR | YES | Native source system document type classification |
| ir_deal_code | VARCHAR | YES | Policy # from IR UserKey1 |
| ir_fund_name | VARCHAR | YES | Claim # from IR UserKey2 |
| ir_assigned_to | VARCHAR | YES | IR workflow assignee (email) |
| ir_date_created | TIMESTAMP_NTZ | YES | When document was created in source system |
| ir_metadata | VARIANT | YES | Full JSON sidecar from metadata stage |
| ingestion_status | VARCHAR | YES | State machine: PENDING / PROCESSING / COMPLETE / FAILED / ABANDONED / SKIPPED |
| processing_version | INT | YES | Version number; increments when file changes or is force-reprocessed |
| force_reprocess | BOOLEAN | YES | Admin flag: TRUE triggers new version regardless of content |
| first_seen_at | TIMESTAMP_NTZ | YES | When file was first detected on stage |
| last_seen_at | TIMESTAMP_NTZ | YES | Last time file was seen during a stage scan |
| processing_started_at | TIMESTAMP_NTZ | YES | When PROCESSING state was entered |
| processing_completed_at | TIMESTAMP_NTZ | YES | When COMPLETE state was entered |
| processing_attempts | INT | YES | Count of parse attempts (resets on force-reprocess) |
| last_error | VARCHAR | YES | Error message from most recent failure |
| error_stage | VARCHAR | YES | Which pipeline stage failed: PARSE / CLASSIFY / EXTRACT |
| content_hash | VARCHAR | YES | SHA2 of extracted text — used for change detection after parse |
| previous_content_hash | VARCHAR | YES | Prior content_hash for diff tracking |
| created_by | VARCHAR | YES | User who triggered registration |
| updated_at | TIMESTAMP_NTZ | YES | Timestamp of last row modification |

**Indexes:** Clustered by `(source_folder, ingestion_status)`  
**Constraints:** `PK (registry_id)`, `UNIQUE (file_path, processing_version)`

---

### `parsed_documents`

AI_PARSE_DOCUMENT output — raw text and structure per document version.

| Column | Type | Description |
|---|---|---|
| parse_id | VARCHAR | UUID PK |
| file_path | VARCHAR | FK to ingestion_registry |
| processing_version | INT | FK to ingestion_registry |
| file_format | VARCHAR | Format from registry |
| parse_mode | VARCHAR | OCR or LAYOUT |
| parse_result | VARIANT | Full AI_PARSE_DOCUMENT JSON response |
| page_count | INT | Total pages in document |
| raw_content | VARCHAR | Concatenated full text across all pages |
| parse_status | VARCHAR | PENDING / COMPLETE / FAILED |
| parse_error | VARCHAR | Error message if failed |
| parse_started_at | TIMESTAMP_NTZ | Parse start time |
| parse_completed_at | TIMESTAMP_NTZ | Parse completion time |
| parse_duration_ms | BIGINT | Elapsed parse time |

---

### `document_pages`

One row per page — optimized for granular Cortex Search retrieval.

| Column | Type | Description |
|---|---|---|
| page_id | VARCHAR | UUID PK |
| file_path | VARCHAR | FK to parsed_documents |
| processing_version | INT | FK to parsed_documents |
| page_index | INT | 0-based page number |
| page_content | VARCHAR | Text content of this page |
| total_pages | INT | Total pages in the document |
| ir_file_id | VARCHAR | Denormalized from registry |
| source_folder | VARCHAR | Denormalized from registry (for clustering) |
| ir_deal_code | VARCHAR | Denormalized from registry |
| ir_fund_name | VARCHAR | Denormalized from registry |

---

### `classified_documents`

AI_CLASSIFY output with confidence scoring.

| Column | Type | Description |
|---|---|---|
| classification_id | VARCHAR | UUID PK |
| file_path | VARCHAR | FK |
| processing_version | INT | FK |
| source_folder | VARCHAR | Denormalized for clustering |
| ai_classification | VARIANT | Full AI_CLASSIFY JSON response (labels array) |
| primary_document_type | VARCHAR | Highest-confidence label (first in array) |
| all_document_types | ARRAY | All returned labels |
| confidence_score | FLOAT | Estimated confidence (0.95=1 label, 0.50=4+ labels) |
| ir_document_type | VARCHAR | Native source system type (for comparison) |
| classification_match | BOOLEAN | TRUE if AI classification matches IR native type |
| needs_review | BOOLEAN | TRUE if confidence < threshold (default 0.70) |
| classified_at | TIMESTAMP_NTZ | Classification timestamp |

---

### `document_attributes`

AI_EXTRACT output — infrastructure PE key attributes.

| Column | Type | Description |
|---|---|---|
| attribute_id | VARCHAR | UUID PK |
| file_path | VARCHAR | FK |
| processing_version | INT | FK |
| extracted_attributes | VARIANT | Full AI_EXTRACT JSON response |
| document_date | DATE | Document creation/issuance date |
| target_company | VARCHAR | Named insured or portfolio company |
| deal_code | VARCHAR | Policy or binder number (COALESCE with ir_deal_code) |
| fund_name | VARCHAR | Claim or loss number |
| sponsor_name | VARCHAR | Deal company or Lloyd's syndicate |
| co_investors | VARCHAR | Co-investors, co-lead investors, or LP co-invest partners |
| sector | VARCHAR | Digital Infrastructure, Transportation, Energy Transition, Water, Communications, etc. |
| deal_stage | VARCHAR | Deals-Made / Occurrence / Deals-Made-and-Reported |
| investment_date | DATE | Date of investment closing |
| effective_date | DATE | Policy inception date |
| expiration_date | DATE | Policy expiration date |
| exit_date | DATE | Date of exit or expected exit |
| enterprise_value | VARCHAR | Per-claim limit as text (e.g., "$5,000,000") |
| equity_check | VARCHAR | Aggregate limit as text |
| target_irr | VARCHAR | SIR or deductible as text |
| monetary_amounts | VARIANT | All financial values as structured JSON |
| exclusions_noted | VARCHAR | Key exclusions mentioned |
| action_required | VARCHAR | Next steps, deadlines, notice requirements |
| doc_status | VARCHAR | bound / quoted / open / closed / denied / settled / in-litigation |
| doc_summary | VARCHAR | 2-3 sentence AI-generated summary |
| extraction_confidence | FLOAT | Overall extraction quality estimate |
| low_confidence_fields | ARRAY | Fields where extraction may be unreliable |
| extracted_at | TIMESTAMP_NTZ | Extraction timestamp |

---

### `document_catalog` (Dynamic Table)

Unified view of the latest COMPLETE version of each document, with overrides applied.

Inherits all columns from `document_attributes` + `classified_documents` + `ingestion_registry` + `parsed_documents`. See individual tables above.

Additional columns:
| Column | Type | Description |
|---|---|---|
| upload_timestamp | TIMESTAMP_NTZ | Alias of `first_seen_at` |
| full_text | VARCHAR | Full extracted text (from `parsed_documents.raw_content`) |

**Refresh:** TARGET_LAG = 1 hour  
**Row Access Policy:** `deal_intel_folder_policy` on `source_folder` column

---

## Schema: TELEMETRY

### `pipeline_events`

Central event log — all pipeline and user activity.

| Column | Type | Description |
|---|---|---|
| event_id | VARCHAR | UUID PK |
| event_time | TIMESTAMP_NTZ | Event timestamp |
| event_type | VARCHAR | See event type catalog below |
| stage_name | VARCHAR | INGEST / PARSE / CLASSIFY / EXTRACT / CATALOG / SEARCH / ANALYST / AGENT / FEEDBACK / OVERRIDE / ADMIN / ALERT |
| file_path | VARCHAR | Related file (if applicable) |
| ir_file_id | VARCHAR | source system File ID |
| source_folder | VARCHAR | Source folder (organizational grouping) |
| user_name | VARCHAR | Snowflake user who triggered event |
| warehouse_name | VARCHAR | Warehouse used |
| status | VARCHAR | SUCCESS / FAILED / SKIPPED / RETRY / QUEUED / TRIGGERED |
| duration_ms | BIGINT | Elapsed time in milliseconds |
| error_message | VARCHAR | Error detail if status=FAILED |
| error_code | VARCHAR | Error code if available |
| credits_used | FLOAT | Snowflake credits consumed |
| rows_processed | BIGINT | Rows affected |
| metadata | VARIANT | Event-specific structured data |

### `agent_audit_log`

Full audit trail of all CoWork/agent interactions.

| Column | Type | Description |
|---|---|---|
| query_id | VARCHAR | UUID PK |
| query_time | TIMESTAMP_NTZ | Query timestamp |
| user_name | VARCHAR | Snowflake user |
| user_role | VARCHAR | Active role at query time |
| question | VARCHAR | User's question text |
| tool_used | VARCHAR | SEARCH / ANALYST / BOTH |
| search_query | VARCHAR | Query sent to Cortex Search |
| analyst_question | VARCHAR | Question sent to Cortex Analyst |
| generated_sql | VARCHAR | SQL generated by Cortex Analyst |
| result_count | INT | Number of results returned |
| response_text | VARCHAR | Agent response (truncated at 1000 chars) |
| latency_ms | BIGINT | Total response latency |
| feedback_score | INT | 1=positive, -1=negative, NULL=none |
| feedback_at | TIMESTAMP_NTZ | When feedback was submitted |
| session_id | VARCHAR | Chat session UUID |

---

## Schema: ADMIN

### `system_config`

Key-value configuration store.

| Key | Default | Type | Description |
|---|---|---|---|
| max_processing_attempts | 3 | INTEGER | Retry limit before ABANDONED |
| search_result_limit | 10 | INTEGER | Default search result count |
| classify_confidence_threshold | 0.70 | FLOAT | Minimum confidence before flagging |
| pipeline_target_lag_minutes | 60 | INTEGER | Target document latency in minutes |
| cost_alert_multiplier | 2.0 | FLOAT | Alert when daily cost exceeds N× average |
| queue_backlog_threshold | 500 | INTEGER | Alert when pending count exceeds this |
| error_rate_threshold_pct | 5 | FLOAT | Alert when error rate exceeds this % |
| enable_pii_masking | true | BOOLEAN | Enable PII masking investments |
| enable_feedback_collection | true | BOOLEAN | Enable thumbs up/down collection |
| max_saved_searches_per_user | 50 | INTEGER | Per-user saved search limit |

### `extraction_overrides`

User-submitted attribute corrections.

| Column | Description |
|---|---|
| override_id | UUID PK |
| file_path | Document the correction applies to |
| processing_version | Document version |
| field_name | Attribute being corrected (e.g., `target_company`) |
| original_value | AI-extracted value before correction |
| corrected_value | Corrected value |
| override_reason | User's explanation |
| submitted_by | User who submitted correction |
| submitted_at | Term Sheet timestamp |
| approved_by | Admin who approved/rejected |
| approved_at | Approval timestamp |
| override_status | PENDING / APPROVED / REJECTED |

### `classification_labels`

Document type labels used by AI_CLASSIFY. Managed via Admin → Classification Labels.

| Column | Type | Description |
|---|---|---|
| label | VARCHAR | PK — document type name (e.g., "Certificate of Deal") |
| category | VARCHAR | Grouping category (e.g., "Compliance", "Deals", "Policy") |
| sort_order | INT | Display order within category |
| is_active | BOOLEAN | Whether the label is available for new classifications |
| created_at | TIMESTAMP_NTZ | When the label was created |

### `lines_of_business`

Configurable investment sectors. Drives the AI_CLASSIFY sector detection and filter dropdowns throughout the app.

| Column | Type | Description |
|---|---|---|
| lob_code | VARCHAR(50) | PK — short code used in match_rules and entitlements (e.g., "DO", "Cyber") |
| lob_name | VARCHAR(200) | Display name used as AI_CLASSIFY label (e.g., "Directors & Officers") |
| description | VARCHAR(500) | Human-readable description of the sector |
| is_active | BOOLEAN | Whether the sector is available for new classifications (default TRUE) |
| sort_order | INT | Display order in dropdowns and tables |
| created_at | TIMESTAMP_NTZ | When the sector was created |

**Seeded values:** Cyber, DO, EO, EPL, Environmental, GL, Property, Excess, Marine, WC

### `extraction_schemas`

Extraction attribute definitions used by AI_EXTRACT. Supports tiered schemas (COMMON, CATEGORY, sector_SPECIFIC).

| Column | Type | Description |
|---|---|---|
| schema_id | INT | Auto-increment PK |
| attribute_name | VARCHAR | Field name to extract |
| attribute_description | VARCHAR | Description passed to AI_EXTRACT prompt |
| attribute_type | VARCHAR | Expected type: text, date, number, array |
| schema_tier | VARCHAR | COMMON / CATEGORY / sector_SPECIFIC |
| document_type | VARCHAR | Display grouping label |
| match_rule | VARIANT | JSON filter: `{"category":"Deals"}` or `{"category":"Deals","lob":"DO"}` |
| sort_order | INT | Order within tier |
| is_active | BOOLEAN | Whether attribute is extracted |

### `saved_searches`

Per-user saved search queries.

| Column | Description |
|---|---|
| search_id | UUID PK |
| user_name | Snowflake user |
| search_name | User-given name |
| query_text | Search query string |
| filter_state | VARIANT — filter selections (folder, type, sector, etc.) |
| result_count | Last known result count |
| last_run_at | When search was last executed |
| is_shared | Whether search is shared with team |

### `search_feedback`

User feedback on search results and agent responses.

| Column | Description |
|---|---|
| feedback_id | UUID PK |
| user_name | User who submitted feedback |
| feedback_type | SEARCH_RESULT or AGENT_RESPONSE |
| query_text | Search query or agent question |
| file_path | Document (for search result feedback) |
| agent_query_id | FK to agent_audit_log (for agent feedback) |
| feedback_score | 1=positive, -1=negative |
| feedback_comment | Optional text comment |

---

## Schema: APP (Views)

All views in `DEAL_INTEL.APP` expose data from DATA and TELEMETRY schemas with row-level security applied. Users must use APP schema views — direct table access is restricted.

| View | Source | Security |
|---|---|---|
| v_document_catalog | document_catalog | Row access policy on source_folder |
| v_pipeline_health | TELEMETRY.v_pipeline_health | Admin only |
| v_ingestion_registry | ingestion_registry | Admin only |
| v_cost_by_folder | TELEMETRY.v_cost_by_folder | Admin only |
| v_search_analytics | TELEMETRY.v_search_analytics | Admin only |
| v_quality_metrics | TELEMETRY.v_quality_metrics | Admin only |
| v_error_summary | TELEMETRY.v_error_summary | Admin only |
| v_agent_audit_log | agent_audit_log | Anonymized (no response text) |

---

## Schema: SERVICES (Cortex AI Services)

### `deal_analytics_sv`

**Purpose:** Semantic view over `document_catalog` for Cortex Analyst natural language to SQL. Powers the "Ask an Analytics Question" NL box on the Analytics page via the `/api/analyst` route.

**Source:** `DEAL_INTEL.DATA.document_catalog`

**Access:** Granted to `DEAL_INTEL_USER` and `DEAL_INTEL_ADMIN`

| Column | Type | Semantic Role | Description |
|---|---|---|---|
| `file_path` | STRING | DIMENSION | Full path to the source document file on stage |
| `ir_file_id` | STRING | DIMENSION | source system File ID — unique identifier in source system |
| `source_folder` | STRING | DIMENSION | Source folder: Deals, Deal Sourcing, Redeal, Compliance, Correspondence, Accounting, Investments |
| `ir_assigned_to` | STRING | DIMENSION | Person assigned in source system workflow |
| `ir_deal_code` | STRING | DIMENSION | Policy number from source system UserKey1 |
| `ir_fund_name` | STRING | DIMENSION | Claim/loss number from source system UserKey2 |
| `document_type` | STRING | DIMENSION | AI-classified document type (Term Sheet, IC Presentation, Investment Memo, etc.) |
| `file_format` | STRING | DIMENSION | Source format: TIFF, PDF, DOCX, JPEG, PNG, HTML, TXT |
| `classification_confidence` | FLOAT | MEASURE | AI classification confidence 0–1 (below 0.70 = review recommended) |
| `needs_review` | BOOLEAN | DIMENSION | True if confidence below configured threshold |
| `target_company` | STRING | DIMENSION | Named insured or portfolio company organization |
| `sponsor_name` | STRING | DIMENSION | Deal company or Lloyd's syndicate |
| `co_investors` | STRING | DIMENSION | Co-investors, co-lead investors, or LP co-invest partners |
| `sector` | STRING | DIMENSION | Infrastructure sector: Digital Infrastructure, Transportation, Energy Transition, Water, Communications, Conventional Power |
| `deal_stage` | STRING | DIMENSION | Coverage trigger: Deals-Made, Occurrence, Deals-Made-and-Reported |
| `document_date` | DATE | DIMENSION | Document creation or effective date |
| `investment_date` | DATE | DIMENSION | Date of investment closing |
| `effective_date` | DATE | DIMENSION | Investment closing date |
| `expiration_date` | DATE | DIMENSION | Expected exit date |
| `exit_date` | DATE | DIMENSION | Date of exit or expected exit |
| `enterprise_value` | STRING | DIMENSION | Per-claim limit as text (e.g. "$5,000,000") |
| `equity_check` | STRING | DIMENSION | Policy aggregate limit as text (e.g. "$10,000,000") |
| `target_irr` | STRING | DIMENSION | SIR or deductible as text (e.g. "$250,000 SIR") |
| `doc_status` | STRING | DIMENSION | Status: bound, quoted, declined, open, closed, reserved, denied, settled, in-litigation |
| `exclusions_noted` | STRING | DIMENSION | Key exclusions: prior knowledge, pollution, war, bodily injury, cyber, etc. |
| `action_required` | STRING | DIMENSION | Required follow-up actions or deadlines |
| `upload_timestamp` | TIMESTAMP | DIMENSION | When the document was first seen in the ingestion stage |
| `page_count` | INTEGER | MEASURE | Total pages in the document |

**Example analytics questions (handled by Cortex Analyst):**
- "How many Digital Infrastructure deals are open by month this year?"
- "What is the breakdown of documents by sector?"
- "Which source folders have the most low-confidence classifications?"
- "Show me total claim count by insured sorted by open deals"
- "What is the average page count by document type?"
