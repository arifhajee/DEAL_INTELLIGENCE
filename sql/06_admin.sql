-- =============================================================================
-- DEAL_INTEL: Admin Tables and Stored Procedures
-- File: sql/06_admin.sql
-- Description: Config, reprocess queue, saved searches, bookmarks, feedback
-- Run as: DEAL_INTEL_ADMIN after 05_intelligence.sql
-- =============================================================================
-- INGESTION STAGES: Registry of stages to scan for new documents
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.ingestion_stages (
    stage_name     VARCHAR NOT NULL,
    description    VARCHAR,
    path_prefix    VARCHAR DEFAULT '',
    file_pattern   VARCHAR DEFAULT '.*\\.(tif|tiff|pdf|docx|pptx|jpg|jpeg|png|html|txt)$',
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by     VARCHAR DEFAULT CURRENT_USER(),
    CONSTRAINT pk_ingestion_stages PRIMARY KEY (stage_name)
)
COMMENT = 'Registry of stages to scan for new documents during ingestion';

-- Seed default stages
MERGE INTO DEAL_INTEL.ADMIN.ingestion_stages t
USING (
  SELECT $1 AS stage_name, $2 AS description, $3 AS path_prefix FROM VALUES
    ('DEAL_INTEL.DATA.sample_stage', 'Sample/demo documents for testing', ''),
    ('DEAL_INTEL.DATA.deal_documents_stage', 'Deal document uploads', 'deals/')
) s ON t.stage_name = s.stage_name
WHEN NOT MATCHED THEN INSERT (stage_name, description, path_prefix)
  VALUES (s.stage_name, s.description, s.path_prefix);

-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;
USE WAREHOUSE DEAL_INTEL_WH;

-- =============================================================================
-- SYSTEM CONFIGURATION: Key-value store for pipeline settings
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.system_config (
    config_key      VARCHAR         NOT NULL,
    config_value    VARCHAR         NOT NULL,
    config_type     VARCHAR         DEFAULT 'STRING', -- STRING, INTEGER, FLOAT, BOOLEAN, JSON
    description     VARCHAR,
    updated_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    updated_by      VARCHAR         DEFAULT CURRENT_USER(),
    CONSTRAINT pk_config PRIMARY KEY (config_key)
)
COMMENT = 'System configuration — pipeline settings, thresholds, AI parameters';

-- Seed default configuration
MERGE INTO DEAL_INTEL.ADMIN.system_config t
USING (
  SELECT $1 AS config_key, $2 AS config_value, $3 AS config_type, $4 AS description FROM VALUES
    ('max_processing_attempts',         '3',        'INTEGER',  'Max pipeline retry attempts before ABANDONED status'),
    ('search_result_limit',             '10',       'INTEGER',  'Default Cortex Search result count'),
    ('classify_confidence_threshold',   '0.70',     'FLOAT',    'Minimum confidence before flagging for human review'),
    ('pipeline_target_lag_minutes',     '60',       'INTEGER',  'Target document-to-searchable latency in minutes'),
    ('cost_alert_multiplier',           '2.0',      'FLOAT',    'Alert when daily credits exceed N× 7-day average'),
    ('queue_backlog_threshold',         '500',      'INTEGER',  'Alert when pending doc count exceeds this'),
    ('error_rate_threshold_pct',        '5',        'FLOAT',    'Alert when 1-hour error rate exceeds this percentage'),
    ('enable_pii_masking',              'true',     'BOOLEAN',  'Enable PII masking policies on sensitive fields'),
    ('enable_feedback_collection',      'true',     'BOOLEAN',  'Enable user thumbs up/down feedback collection'),
    ('max_saved_searches_per_user',     '50',       'INTEGER',  'Maximum saved searches per user'),
    ('admin_email',                     '',         'STRING',   'Email address for pipeline alert notifications'),
    ('parse_image_mode',                'OCR',      'STRING',   'Parse mode for TIFF/JPEG/PNG: OCR'),
    ('parse_doc_mode',                  'LAYOUT',   'STRING',   'Parse mode for PDF/DOCX/HTML: LAYOUT'),
    ('search_embedding_model',          'snowflake-arctic-embed-l-v2.0', 'STRING', 'Cortex Search embedding model'),
    ('agent_model',                     'claude-sonnet-4-5', 'STRING', 'LLM model for Cortex Agent')
) s ON t.config_key = s.config_key
WHEN NOT MATCHED THEN INSERT (config_key, config_value, config_type, description)
  VALUES (s.config_key, s.config_value, s.config_type, s.description);

-- =============================================================================
-- SAVED SEARCHES: Per-user saved search queries with filter state
-- Supports visibility scoping: personal (default), role-based, or global
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.saved_searches (
    search_id       VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    user_name       VARCHAR         DEFAULT CURRENT_USER(),
    search_name     VARCHAR         NOT NULL,
    query_text      VARCHAR,
    filters_json    VARCHAR,        -- JSON string: {document_type, source_folder, sector, date_from, date_to, status, file_format}
    visibility      VARCHAR         DEFAULT 'personal',     -- personal | role | global
    shared_role     VARCHAR,        -- role name when visibility='role'
    last_run_at     TIMESTAMP_NTZ,
    created_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_saved_searches PRIMARY KEY (search_id)
)
COMMENT = 'Saved search queries — personal, role-scoped, or global visibility';

-- =============================================================================
-- DOCUMENT BOOKMARKS: Per-user pinned documents
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.document_bookmarks (
    bookmark_id     VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    user_name       VARCHAR         DEFAULT CURRENT_USER(),
    file_path       VARCHAR         NOT NULL,
    ir_file_id      VARCHAR,
    document_type   VARCHAR,
    target_company  VARCHAR,
    personal_note   VARCHAR,
    created_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_bookmarks PRIMARY KEY (bookmark_id),
    CONSTRAINT uq_bookmark UNIQUE (user_name, file_path)
)
COMMENT = 'User-pinned documents — personal bookmarks persisted between sessions';

-- =============================================================================
-- SEARCH FEEDBACK: Thumbs up/down on search results and agent responses
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.search_feedback (
    feedback_id     VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path       VARCHAR,
    feedback_type   VARCHAR,        -- thumbs_up / thumbs_down
    query_text      VARCHAR,
    document_type   VARCHAR,
    submitted_by    VARCHAR         DEFAULT CURRENT_USER(),
    submitted_at    TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_feedback PRIMARY KEY (feedback_id)
)
COMMENT = 'User feedback on search results and agent responses — quality improvement data';

-- =============================================================================
-- EXTRACTION SCHEMAS: Configurable AI_EXTRACT attributes per document type
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.extraction_schemas (
    schema_id               VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    schema_tier             VARCHAR(20)     DEFAULT 'CATEGORY',     -- COMMON, CATEGORY, SECTOR_SPECIFIC
    document_type           VARCHAR         NOT NULL,               -- 'Common', category name, or 'Category - Sector'
    attribute_name          VARCHAR         NOT NULL,
    attribute_description   VARCHAR         NOT NULL,               -- prompt for AI_EXTRACT
    attribute_type          VARCHAR         DEFAULT 'VARCHAR',      -- VARCHAR, DATE, NUMBER, VARIANT
    is_required             BOOLEAN         DEFAULT TRUE,
    sort_order              INTEGER         DEFAULT 0,
    match_rule              VARCHAR         DEFAULT NULL,           -- JSON string: {"category":"X"} or {"category":"X","sector":"Y"}
    version                 INT             DEFAULT 1,
    status                  VARCHAR(20)     DEFAULT 'PUBLISHED',   -- DRAFT or PUBLISHED
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    updated_by              VARCHAR         DEFAULT CURRENT_USER(),
    CONSTRAINT pk_extraction_schemas PRIMARY KEY (schema_id),
    CONSTRAINT uq_extraction_schemas UNIQUE (schema_tier, document_type, attribute_name)
)
COMMENT = 'Layered extraction schema: COMMON > CATEGORY > SECTOR_SPECIFIC';

-- =============================================================================
-- SEED: 3-Tier Extraction Schema for Infrastructure PE
-- Tier 1: COMMON — always extracted from every document
-- Tier 2: CATEGORY — applied when doc matches a category (Deal Sourcing, DD, etc.)
-- Tier 3: SECTOR_SPECIFIC — applied when category + sector both match
-- =============================================================================

-- Clear and reseed (idempotent on redeploy)
DELETE FROM DEAL_INTEL.ADMIN.extraction_schemas;

-- ─── TIER 1: COMMON (always extracted) ─────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier) VALUES
  ('Common', 'document_date',     'Date the document was created, issued, or effective', 'DATE', 1, 'COMMON'),
  ('Common', 'target_company',    'Target company or portfolio company name', 'VARCHAR', 2, 'COMMON'),
  ('Common', 'deal_name',         'Internal deal or project code name', 'VARCHAR', 3, 'COMMON'),
  ('Common', 'sponsor_name',      'Lead sponsor or GP firm name', 'VARCHAR', 4, 'COMMON'),
  ('Common', 'sector',            'Infrastructure sector: Digital Infrastructure, Transportation, Energy Transition, Water, Social Infrastructure, Communications, Conventional Power', 'VARCHAR', 5, 'COMMON'),
  ('Common', 'deal_stage',        'Deal lifecycle stage: Sourcing, Due Diligence, IC Review, Closing, Portfolio, Exited', 'VARCHAR', 6, 'COMMON'),
  ('Common', 'fund_name',         'Fund vehicle name', 'VARCHAR', 7, 'COMMON'),
  ('Common', 'doc_status',        'Status: active, draft, final, approved, pending IC, closed, exited', 'VARCHAR', 8, 'COMMON'),
  ('Common', 'doc_summary',       'Two to three sentence summary of the document purpose and key deal information', 'VARCHAR', 9, 'COMMON');

-- ─── TIER 2: CATEGORY — Deal Sourcing ─────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Deal Sourcing', 'enterprise_value',       'Total enterprise value or TEV of target', 'VARCHAR', 1, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'equity_check',           'Equity investment amount or check size', 'VARCHAR', 2, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'net_debt',               'Net debt at target level', 'VARCHAR', 3, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'target_irr',             'Target or projected gross/net IRR', 'VARCHAR', 4, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'target_moic',            'Target or projected MOIC multiple', 'VARCHAR', 5, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'co_investors',           'Co-invest partners or co-lead investors', 'VARCHAR', 6, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'geography',              'Primary geography of target asset', 'VARCHAR', 7, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'investment_thesis',      'Core investment thesis or value creation levers', 'VARCHAR', 8, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'key_risks',              'Key investment risks and mitigants', 'VARCHAR', 9, 'CATEGORY', '{"category":"Deal Sourcing"}'),
  ('Deal Sourcing', 'action_required',        'Required next steps, approvals, or deadlines', 'VARCHAR', 10, 'CATEGORY', '{"category":"Deal Sourcing"}');

-- ─── TIER 2: CATEGORY — Due Diligence ─────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Due Diligence', 'dd_provider',            'Name of advisory firm conducting the diligence', 'VARCHAR', 1, 'CATEGORY', '{"category":"Due Diligence"}'),
  ('Due Diligence', 'dd_scope',               'Scope of diligence: commercial, legal, tax, environmental, technical, insurance', 'VARCHAR', 2, 'CATEGORY', '{"category":"Due Diligence"}'),
  ('Due Diligence', 'key_findings',           'Material findings or issues identified', 'VARCHAR', 3, 'CATEGORY', '{"category":"Due Diligence"}'),
  ('Due Diligence', 'red_flags',              'Red flags, deal-breakers, or significant concerns', 'VARCHAR', 4, 'CATEGORY', '{"category":"Due Diligence"}'),
  ('Due Diligence', 'recommendation',         'Advisor recommendation: proceed, proceed with conditions, or do not proceed', 'VARCHAR', 5, 'CATEGORY', '{"category":"Due Diligence"}'),
  ('Due Diligence', 'conditions_precedent',   'Conditions or items required before closing', 'VARCHAR', 6, 'CATEGORY', '{"category":"Due Diligence"}');

-- ─── TIER 2: CATEGORY — Transaction ──────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Transaction', 'purchase_price',           'Total purchase price or enterprise value', 'VARCHAR', 1, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'closing_date',             'Expected or actual transaction closing date', 'DATE', 2, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'escrow_amount',            'Escrow or holdback amount and survival period', 'VARCHAR', 3, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'earn_out',                 'Earn-out or contingent consideration terms', 'VARCHAR', 4, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'regulatory_approvals',     'Required regulatory approvals (HSR, CFIUS, sector-specific)', 'VARCHAR', 5, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'financing_structure',      'Debt structure: senior, mezzanine, revolver, term loan details', 'VARCHAR', 6, 'CATEGORY', '{"category":"Transaction"}'),
  ('Transaction', 'key_reps_warranties',      'Material representations and warranties provisions', 'VARCHAR', 7, 'CATEGORY', '{"category":"Transaction"}');

-- ─── TIER 2: CATEGORY — Portfolio Management ─────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Portfolio', 'revenue',                    'Revenue figure (LTM, annual, or quarterly)', 'VARCHAR', 1, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'ebitda',                     'EBITDA or Adjusted EBITDA figure', 'VARCHAR', 2, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'capex',                      'Capital expenditure (growth + maintenance)', 'VARCHAR', 3, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'current_valuation',          'Current valuation or NAV', 'VARCHAR', 4, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'realized_moic',              'Realized or marked MOIC', 'VARCHAR', 5, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'operational_kpis',           'Key operational metrics specific to the business', 'VARCHAR', 6, 'CATEGORY', '{"category":"Portfolio"}'),
  ('Portfolio', 'value_creation_initiatives', 'Active value creation or operational improvement initiatives', 'VARCHAR', 7, 'CATEGORY', '{"category":"Portfolio"}');

-- ─── TIER 2: CATEGORY — Investor Relations ────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Investor Relations', 'fund_size',          'Total fund commitments', 'VARCHAR', 1, 'CATEGORY', '{"category":"Investor Relations"}'),
  ('Investor Relations', 'deployed_capital',   'Amount of capital deployed or called', 'VARCHAR', 2, 'CATEGORY', '{"category":"Investor Relations"}'),
  ('Investor Relations', 'tvpi',               'Total Value to Paid-In (TVPI) multiple', 'VARCHAR', 3, 'CATEGORY', '{"category":"Investor Relations"}'),
  ('Investor Relations', 'dpi',                'Distributions to Paid-In (DPI) multiple', 'VARCHAR', 4, 'CATEGORY', '{"category":"Investor Relations"}'),
  ('Investor Relations', 'net_irr',            'Net IRR since inception', 'VARCHAR', 5, 'CATEGORY', '{"category":"Investor Relations"}'),
  ('Investor Relations', 'capital_activity',   'Capital calls, distributions, or recycling activity', 'VARCHAR', 6, 'CATEGORY', '{"category":"Investor Relations"}');

-- ─── TIER 2: CATEGORY — Compliance ────────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Compliance', 'filing_type',              'Type: HSR, CFIUS, state regulatory, environmental permit', 'VARCHAR', 1, 'CATEGORY', '{"category":"Compliance"}'),
  ('Compliance', 'jurisdiction',             'Regulatory jurisdiction or agency', 'VARCHAR', 2, 'CATEGORY', '{"category":"Compliance"}'),
  ('Compliance', 'filing_deadline',          'Submission deadline', 'DATE', 3, 'CATEGORY', '{"category":"Compliance"}'),
  ('Compliance', 'approval_status',          'Status of regulatory approval', 'VARCHAR', 4, 'CATEGORY', '{"category":"Compliance"}'),
  ('Compliance', 'conditions_imposed',       'Conditions or remedies imposed by regulator', 'VARCHAR', 5, 'CATEGORY', '{"category":"Compliance"}');

-- ─── TIER 2: CATEGORY — Financial ────────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Financial', 'revenue',                   'Revenue for period', 'VARCHAR', 1, 'CATEGORY', '{"category":"Financial"}'),
  ('Financial', 'ebitda',                    'EBITDA or Adjusted EBITDA', 'VARCHAR', 2, 'CATEGORY', '{"category":"Financial"}'),
  ('Financial', 'net_income',               'Net income or loss', 'VARCHAR', 3, 'CATEGORY', '{"category":"Financial"}'),
  ('Financial', 'total_debt',               'Total debt outstanding', 'VARCHAR', 4, 'CATEGORY', '{"category":"Financial"}'),
  ('Financial', 'leverage_ratio',           'Net debt / EBITDA leverage ratio', 'VARCHAR', 5, 'CATEGORY', '{"category":"Financial"}');

-- =============================================================================
-- TIER 3: SECTOR_SPECIFIC — Applied when category + sector both match
-- =============================================================================

-- ─── Deal Sourcing + Digital Infrastructure ──────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Deal Sourcing - DINFRA', 'total_capacity_mw',     'Total IT capacity in megawatts (MW)', 'VARCHAR', 1, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"DINFRA"}'),
  ('Deal Sourcing - DINFRA', 'utilization_rate',      'Current capacity utilization percentage', 'VARCHAR', 2, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"DINFRA"}'),
  ('Deal Sourcing - DINFRA', 'development_pipeline',  'Development pipeline capacity (MW or fiber miles)', 'VARCHAR', 3, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"DINFRA"}'),
  ('Deal Sourcing - DINFRA', 'contract_duration',     'Weighted average remaining contract term (years)', 'VARCHAR', 4, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"DINFRA"}');

-- ─── Deal Sourcing + Energy Transition ───────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Deal Sourcing - ENERGY', 'operating_capacity_gw',  'Operating generation capacity in GW', 'VARCHAR', 1, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"ENERGY"}'),
  ('Deal Sourcing - ENERGY', 'ppa_coverage',           'Percentage of capacity under PPA', 'VARCHAR', 2, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"ENERGY"}'),
  ('Deal Sourcing - ENERGY', 'technology_mix',         'Generation technology: solar, wind, battery, gas', 'VARCHAR', 3, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"ENERGY"}'),
  ('Deal Sourcing - ENERGY', 'merchant_exposure',      'Percentage of revenue exposed to merchant pricing', 'VARCHAR', 4, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"ENERGY"}');

-- ─── Deal Sourcing + Transportation ──────────────────────────────────────────
INSERT INTO DEAL_INTEL.ADMIN.extraction_schemas (document_type, attribute_name, attribute_description, attribute_type, sort_order, schema_tier, match_rule) VALUES
  ('Deal Sourcing - TRANS', 'asset_base',            'Number and type of assets (ports, terminals, fleet, warehouses)', 'VARCHAR', 1, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"TRANS"}'),
  ('Deal Sourcing - TRANS', 'throughput_volume',     'Annual throughput or volume (TEUs, tons, shipments)', 'VARCHAR', 2, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"TRANS"}'),
  ('Deal Sourcing - TRANS', 'concession_expiry',    'Concession or lease expiration dates', 'VARCHAR', 3, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"TRANS"}'),
  ('Deal Sourcing - TRANS', 'customer_concentration', 'Top customer concentration (% of revenue)', 'VARCHAR', 4, 'SECTOR_SPECIFIC', '{"category":"Deal Sourcing","sector":"TRANS"}');

GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.extraction_schemas TO ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- USER PREFERENCES: Per-user app settings
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.user_preferences (
    user_name           VARCHAR         NOT NULL,
    default_folder      VARCHAR,        -- default source_folder filter
    default_sector         VARCHAR,        -- default sector filter
    results_per_page    INT             DEFAULT 25,
    theme               VARCHAR         DEFAULT 'light',
    date_format         VARCHAR         DEFAULT 'YYYY-MM-DD',
    notifications_on    BOOLEAN         DEFAULT TRUE,
    onboarding_complete BOOLEAN         DEFAULT FALSE,
    updated_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_prefs PRIMARY KEY (user_name)
)
COMMENT = 'Per-user application preferences and settings';

-- =============================================================================
-- REPROCESS QUEUE: Admin-triggered reprocess jobs with tracking
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.reprocess_queue (
    queue_id        VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    job_name        VARCHAR,
    file_paths      VARIANT,        -- ARRAY of file paths OR NULL for bulk
    source_folder       VARCHAR,        -- bulk by folder
    file_format     VARCHAR,        -- bulk by format
    from_date       TIMESTAMP_NTZ,  -- bulk by date range
    to_date         TIMESTAMP_NTZ,
    files_queued    INT             DEFAULT 0,
    files_complete  INT             DEFAULT 0,
    files_failed    INT             DEFAULT 0,
    status          VARCHAR         DEFAULT 'QUEUED',  -- QUEUED/RUNNING/COMPLETE/FAILED
    requested_by    VARCHAR         DEFAULT CURRENT_USER(),
    requested_at    TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    started_at      TIMESTAMP_NTZ,
    completed_at    TIMESTAMP_NTZ,
    notes           VARCHAR,
    CONSTRAINT pk_queue PRIMARY KEY (queue_id)
)
COMMENT = 'Admin-submitted reprocess jobs — single file or bulk operations';

-- =============================================================================
-- TABLE: classification_labels — document type labels for AI_CLASSIFY
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.classification_labels (
    label       VARCHAR(200) NOT NULL,
    category    VARCHAR(100) DEFAULT 'General',
    sort_order  INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT uq_classification_label UNIQUE (label)
)
COMMENT = 'Configurable document classification labels used by AI_CLASSIFY pipeline';

-- =============================================================================
-- TABLE: notification_config — Alert routing rules for pipeline events
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.notification_config (
    id              VARCHAR(36) DEFAULT UUID_STRING(),
    channel_type    VARCHAR(20) NOT NULL,   -- 'webhook' or 'email'
    endpoint        VARCHAR(1000) NOT NULL, -- URL or email address
    event_types     ARRAY NOT NULL,         -- e.g. ['ALERT','INGEST']
    threshold_value INT DEFAULT 0,          -- 0 = all events
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (id)
)
COMMENT = 'Alert routing rules — defines where pipeline events are sent';

-- =============================================================================
-- EXTRACTION OVERRIDES TABLE (created in 03_processing.sql but admin-owned)
-- =============================================================================
-- Already created in 03_processing.sql as DEAL_INTEL.ADMIN.extraction_overrides

-- =============================================================================
-- STORED PROCEDURE: Apply approved overrides (admin action)
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.ADMIN.sp_approve_override(
    p_override_id VARCHAR
)
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
BEGIN
    UPDATE DEAL_INTEL.ADMIN.extraction_overrides
    SET override_status = 'APPROVED',
        approved_by     = CURRENT_USER(),
        approved_at     = CURRENT_TIMESTAMP()
    WHERE override_id = :p_override_id
      AND override_status = 'PENDING';

    IF (SQLROWCOUNT = 0) THEN
        RETURN 'ERROR: Override not found or already actioned: ' || :p_override_id;
    END IF;

    RETURN 'OK: Override approved. Will be reflected in document_catalog on next Dynamic Table refresh.';
END;
$$;

-- =============================================================================
-- STORED PROCEDURE: Get admin summary dashboard stats
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.ADMIN.sp_get_dashboard_stats()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
DECLARE
    v_total INT;
    v_pending INT;
    v_failed INT;
    v_reviews INT;
    v_overrides INT;
    v_queries INT;
BEGIN
    SELECT COUNT(*) INTO :v_total FROM DEAL_INTEL.DATA.ingestion_registry WHERE ingestion_status = 'COMPLETE';
    SELECT COALESCE(pending_count, 0) INTO :v_pending FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;
    SELECT COALESCE(failed_count, 0) INTO :v_failed FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;
    SELECT COUNT(*) INTO :v_reviews FROM DEAL_INTEL.DATA.classified_documents WHERE needs_review = TRUE AND classified_at >= DATEADD('DAY', -7, CURRENT_TIMESTAMP());
    SELECT COUNT(*) INTO :v_overrides FROM DEAL_INTEL.ADMIN.extraction_overrides WHERE override_status = 'PENDING';
    SELECT COUNT(*) INTO :v_queries FROM DEAL_INTEL.TELEMETRY.agent_audit_log WHERE query_time >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP());

    RETURN OBJECT_CONSTRUCT(
        'total_documents', :v_total,
        'pending_processing', :v_pending,
        'pending_status', IFF(:v_pending > 500, 'WARNING', 'OK'),
        'failed_documents', :v_failed,
        'failed_status', IFF(:v_failed > 50, 'WARNING', 'OK'),
        'pending_reviews', :v_reviews,
        'unreviewed_overrides', :v_overrides,
        'search_queries_24h', :v_queries
    )::VARCHAR;
END;
$$;

-- =============================================================================
-- STORED PROCEDURE: Reset pipeline (admin emergency use)
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.ADMIN.sp_reset_pipeline(
    p_confirm VARCHAR  -- must pass 'CONFIRM_RESET' to prevent accidents
)
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
BEGIN
    IF (:p_confirm != 'CONFIRM_RESET') THEN
        RETURN 'ERROR: Pass ''CONFIRM_RESET'' as parameter to execute this procedure.';
    END IF;

    -- Reset all PROCESSING documents back to PENDING (in case tasks died mid-run)
    UPDATE DEAL_INTEL.DATA.ingestion_registry
    SET ingestion_status    = 'PENDING',
        processing_started_at = NULL,
        updated_at          = CURRENT_TIMESTAMP()
    WHERE ingestion_status = 'PROCESSING';

    -- Log the reset
    INSERT INTO DEAL_INTEL.TELEMETRY.pipeline_events (event_type, stage_name, status, metadata)
    VALUES ('PIPELINE_RESET', 'ADMIN', 'EXECUTED',
            OBJECT_CONSTRUCT('triggered_by', CURRENT_USER(), 'reason', 'Manual pipeline reset'));

    RETURN 'OK: Pipeline reset complete. All PROCESSING documents reset to PENDING.';
END;
$$;

-- Grant admin procedures to admin role
GRANT USAGE ON PROCEDURE DEAL_INTEL.ADMIN.sp_approve_override(VARCHAR) TO ROLE DEAL_INTEL_ADMIN;
GRANT USAGE ON PROCEDURE DEAL_INTEL.ADMIN.sp_get_dashboard_stats() TO ROLE DEAL_INTEL_ADMIN;
GRANT USAGE ON PROCEDURE DEAL_INTEL.ADMIN.sp_reset_pipeline(VARCHAR) TO ROLE DEAL_INTEL_ADMIN;
GRANT USAGE ON PROCEDURE DEAL_INTEL.DATA.sp_force_reprocess(VARCHAR, VARCHAR) TO ROLE DEAL_INTEL_ADMIN;
GRANT USAGE ON PROCEDURE DEAL_INTEL.DATA.sp_bulk_reprocess(VARCHAR, VARCHAR, BOOLEAN) TO ROLE DEAL_INTEL_ADMIN;

-- Grant classification_labels table access
GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.classification_labels TO ROLE DEAL_INTEL_ADMIN;
GRANT SELECT ON DEAL_INTEL.ADMIN.classification_labels TO ROLE DEAL_INTEL_USER;
GRANT SELECT ON DEAL_INTEL.ADMIN.classification_labels TO ROLE DEAL_INTEL_PIPELINE;

-- Grant notification_config table access
GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.notification_config TO ROLE DEAL_INTEL_ADMIN;
GRANT SELECT ON DEAL_INTEL.ADMIN.notification_config TO ROLE DEAL_INTEL_USER;
