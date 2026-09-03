# DEAL_INTEL: Operations Guide

## Daily Operations

### Check Pipeline Health

```sql
SELECT * FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;
```

**Green state:** `pending_count = 0`, `failed_count = 0`, `processing_count = 0`  
**Action needed:** `pending_count > 500` (check tasks), `failed_count > 0` (review errors)

### Check for Errors

```sql
SELECT * FROM DEAL_INTEL.TELEMETRY.v_error_summary
WHERE error_date = CURRENT_DATE()
ORDER BY occurrence_count DESC;
```

### Monitor Cost

```sql
SELECT cost_date, SUM(total_credits) AS daily_credits
FROM DEAL_INTEL.TELEMETRY.v_cost_by_folder
WHERE cost_date >= DATEADD('DAY', -7, CURRENT_DATE())
GROUP BY 1 ORDER BY 1 DESC;
```

---

## Weekly Operations

### Review Low-Confidence Classifications

```sql
SELECT file_path, source_folder, primary_document_type, confidence_score
FROM DEAL_INTEL.DATA.classified_documents
WHERE needs_review = TRUE
  AND classified_at >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
ORDER BY confidence_score ASC;
```

### Review Pending Overrides

```sql
SELECT * FROM DEAL_INTEL.ADMIN.extraction_overrides
WHERE override_status = 'PENDING'
ORDER BY submitted_at ASC;
```

Approve via admin UI or: `CALL DEAL_INTEL.ADMIN.sp_approve_override('<override_id>');`

### Check Search Quality

```sql
SELECT query_date, tool_used, query_count, avg_latency_ms, positive_feedback_pct
FROM DEAL_INTEL.TELEMETRY.v_search_analytics
WHERE query_date >= DATEADD('DAY', -7, CURRENT_DATE())
ORDER BY 1 DESC;
```

---

## Pipeline Management

### Force-Reprocess a Single Document

```sql
CALL DEAL_INTEL.DATA.sp_force_reprocess(
    'documents/my-document.pdf',
    'Content changed on source system'
);
```

### Bulk Reprocess a Source Folder

```sql
-- Dry run first
CALL DEAL_INTEL.DATA.sp_bulk_reprocess('Deals', NULL, TRUE);

-- Execute if dry run looks correct
CALL DEAL_INTEL.DATA.sp_bulk_reprocess('Deals', NULL, FALSE);
```

### Suspend/Resume Tasks

```sql
-- Suspend (maintenance window)
ALTER TASK DEAL_INTEL.DATA.task_01_register_files SUSPEND;

-- Resume
ALTER TASK DEAL_INTEL.DATA.task_01_register_files RESUME;
```

### Reset Stuck PROCESSING Documents

```sql
-- If tasks died mid-run, PROCESSING documents may be stuck
CALL DEAL_INTEL.ADMIN.sp_reset_pipeline('CONFIRM_RESET');
```

---

## Common Troubleshooting

### Documents Not Appearing in Search

1. Check `ingestion_status` in registry:
   ```sql
   SELECT ingestion_status, COUNT(*) FROM DEAL_INTEL.DATA.ingestion_registry GROUP BY 1;
   ```
2. If PENDING: tasks may be suspended. Check `SHOW TASKS IN SCHEMA DEAL_INTEL.DATA;`
3. If COMPLETE but not in catalog: Dynamic Table may not have refreshed. Check `SHOW DYNAMIC TABLES;`
4. If in catalog but not in search: Cortex Search may still be indexing. Wait for TARGET_LAG.

### High Error Rate

1. Check error details:
   ```sql
   SELECT last_error, error_stage, COUNT(*) FROM DEAL_INTEL.DATA.ingestion_registry
   WHERE ingestion_status = 'FAILED' GROUP BY 1,2 ORDER BY 3 DESC;
   ```
2. Common causes:
   - File too large (>100MB): Move to separate processing queue
   - Unsupported format: Check file extension is in allowed list
   - OCR failure: File may be corrupt or encrypted
   - Network timeout: Retry usually resolves

### Cortex Search Not Returning Results

1. Check search service status:
   ```sql
   SHOW CORTEX SEARCH SERVICES IN SCHEMA DEAL_INTEL.SERVICES;
   ```
2. Verify document_catalog has data:
   ```sql
   SELECT COUNT(*) FROM DEAL_INTEL.DATA.document_catalog;
   ```
3. Test with SEARCH_PREVIEW:
   ```sql
   SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
       'DEAL_INTEL.SERVICES.deal_search_svc',
       '{"query":"test","columns":["document_type"],"limit":3}'
   ))['results'];
   ```

---

## Adding a New User

```sql
USE ROLE SECURITYADMIN;

-- Grant based on job function
-- Standard user (search, browse, Q&A)
GRANT ROLE DEAL_INTEL_USER TO USER new.user@company.com;

-- Pipeline operator (reprocess, manage tasks)
GRANT ROLE DEAL_INTEL_PIPELINE TO USER pipeline.user@company.com;

-- Admin (full access including config and overrides)
GRANT ROLE DEAL_INTEL_ADMIN TO USER admin@company.com;
```

Then share the app URL with the user. Retrieve it with:
```bash
snow app open --print-only
```

---

## Updating the Classification Taxonomy

Classification labels and categories are now managed through the Admin UI:

1. Navigate to **Admin → Classification Labels**
2. **Add a label:** Enter a name, select (or create) a category, click Add
3. **Create a category:** Click the folder+ icon next to the category dropdown
4. **Rename a category:** Click the pencil icon on the category header
5. **Delete a category:** Click the trash icon on the category header (removes all labels in it)
6. **Disable a label:** Toggle the switch off (label won't be used for new classifications)

Changes take effect immediately for new documents. To reclassify existing documents, use the Reprocess tab on Pipeline Management.

**SQL alternative:**
```sql
-- Add a new label directly
INSERT INTO DEAL_INTEL.ADMIN.classification_labels (label, category, sort_order, is_active)
VALUES ('New Document Type', 'Deals', 100, TRUE);

-- Re-classify affected documents
CALL DEAL_INTEL.DATA.sp_bulk_reprocess(NULL, NULL, FALSE);
```

---

## Managing Investment Sectors

Investment Sectors are configurable through the Admin UI. The pipeline's sector detection (AI_CLASSIFY) reads active sectors from this table dynamically — no code changes needed to add or remove sectors.

1. Navigate to **Admin → Investment Sectors**
2. **Add a sector:** Click "Add sector", enter code (e.g., `WC`), display name (e.g., `Workers Compensation`), optional description
3. **Edit a sector:** Click the pencil icon to edit name/description inline
4. **Disable a sector:** Toggle the switch off (sector won't be available for new classifications)
5. **Delete a sector:** Click the trash icon (use with caution — existing documents referencing this sector code will retain their value)

**Important:** The `lob_code` must match what's used in `extraction_schemas.match_rule` for sector-specific extraction to work. For example, if you add sector code `Aviation`, you should also add extraction schema entries with `match_rule = '{"category":"...", "lob":"Aviation"}'`.

**SQL alternative:**
```sql
-- Add a new sector
INSERT INTO DEAL_INTEL.ADMIN.lines_of_business (lob_code, lob_name, description, sort_order)
VALUES ('Aviation', 'Aviation Deal', 'Aviation hull and liability coverage', 11);

-- View active sectors
SELECT lob_code, lob_name FROM DEAL_INTEL.ADMIN.lines_of_business
WHERE is_active = TRUE ORDER BY sort_order;
```

---

## Backup & Recovery

The pipeline is fully reproducible from source files on the stage. To recover from data loss:

1. **Registry only:** Re-run `sp_register_new_files()` — rebuilds from stage
2. **Parsed documents:** Re-process via bulk reprocess
3. **Full wipe:** `DROP DATABASE DEAL_INTEL CASCADE` then re-run all 7 SQL scripts
4. **Source documents:** Managed by source system — no backup needed in Snowflake

---

## Scaling Considerations

| Dimension | Guidance |
|---|---|
| > 1M documents | Consider increasing `DEAL_INTEL_WH` to LARGE during bulk initial load |
| High query volume | Create multiple `DEAL_INTEL_QUERY_WH` warehouses for different user groups |
| Multiple regions | Set Cortex Search `CROSS_REGION = TRUE` if users span regions |
| Real-time requirements | Reduce `TARGET_LAG` on tasks and Cortex Search to 15 minutes |
