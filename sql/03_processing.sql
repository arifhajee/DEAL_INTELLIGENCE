-- =============================================================================
-- DEAL_INTEL: AI Processing Pipeline
-- File: sql/03_processing.sql
-- Description: Format-aware parsing, classification, extraction, dynamic catalog
-- Run as: DEAL_INTEL_ADMIN after 02_ingestion.sql
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA DATA;
USE WAREHOUSE DEAL_INTEL_WH;

-- =============================================================================
-- TABLE: parsed_documents — AI_PARSE_DOCUMENT output
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.DATA.parsed_documents (
    parse_id                VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path               VARCHAR         NOT NULL,
    stage_name              VARCHAR         NOT NULL,
    file_format             VARCHAR         NOT NULL,
    processing_version      INT             DEFAULT 1,
    parse_mode              VARCHAR,        -- OCR or LAYOUT
    parse_result            VARIANT,        -- full AI_PARSE_DOCUMENT JSON output
    page_count              INT,
    raw_content             VARCHAR,        -- full concatenated text (all pages)
    parse_status            VARCHAR         DEFAULT 'PENDING',  -- PENDING/COMPLETE/FAILED
    parse_error             VARCHAR,
    parse_started_at        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    parse_completed_at      TIMESTAMP_NTZ,
    parse_duration_ms       BIGINT,
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_parsed PRIMARY KEY (parse_id),
    CONSTRAINT uq_parsed UNIQUE (file_path, processing_version)
)
CLUSTER BY (file_format, parse_status)
COMMENT = 'AI_PARSE_DOCUMENT results — OCR and layout extraction per document version';

-- =============================================================================
-- TABLE: document_pages — One row per page (for granular search)
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.DATA.document_pages (
    page_id             VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path           VARCHAR         NOT NULL,
    processing_version  INT             DEFAULT 1,
    page_index          INT             NOT NULL,
    page_content        VARCHAR,
    total_pages         INT,
    ir_file_id          VARCHAR,
    source_folder           VARCHAR,
    ir_policy_number    VARCHAR,
    ir_claim_number     VARCHAR,
    created_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_pages PRIMARY KEY (page_id),
    CONSTRAINT uq_page UNIQUE (file_path, processing_version, page_index)
)
CLUSTER BY (source_folder, file_path)
CHANGE_TRACKING = TRUE
COMMENT = 'Per-page extracted text — one row per page for granular Cortex Search retrieval';

-- =============================================================================
-- TABLE: classified_documents — AI_CLASSIFY output with confidence
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.DATA.classified_documents (
    classification_id       VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path               VARCHAR         NOT NULL,
    processing_version      INT             DEFAULT 1,
    source_folder               VARCHAR,        -- denormalized for clustering/filtering
    ai_classification       VARIANT,        -- full AI_CLASSIFY JSON (labels + scores)
    primary_document_type   VARCHAR,        -- highest-confidence label
    all_document_types      ARRAY,          -- all labels above threshold
    confidence_score        FLOAT,          -- primary label confidence (0-1)
    ir_document_type        VARCHAR,        -- native source system type for comparison
    classification_match    BOOLEAN,        -- does AI match IR native type?
    needs_review            BOOLEAN,        -- confidence < threshold
    classified_at           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_classified PRIMARY KEY (classification_id),
    CONSTRAINT uq_classified UNIQUE (file_path, processing_version)
)
CLUSTER BY (primary_document_type, source_folder)
COMMENT = 'AI_CLASSIFY results — infrastructure PE document type classification';

-- =============================================================================
-- TABLE: document_attributes — AI_EXTRACT output (VARIANT + typed columns)
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.DATA.document_attributes (
    attribute_id            VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path               VARCHAR         NOT NULL,
    processing_version      INT             DEFAULT 1,
    extracted_attributes    VARIANT,        -- full AI_EXTRACT JSON

    -- Typed columns for analytics (flattened from VARIANT)
    document_date           DATE,
    target_company          VARCHAR,
    deal_name               VARCHAR,
    sponsor_name            VARCHAR,
    co_investors            VARCHAR,
    sector                  VARCHAR,
    deal_stage              VARCHAR,        -- Sourcing / DD / IC / Closing / Portfolio / Exited
    fund_name               VARCHAR,
    geography               VARCHAR,
    enterprise_value        VARCHAR,
    equity_check            VARCHAR,
    net_debt                VARCHAR,
    target_irr              VARCHAR,
    target_moic             VARCHAR,
    investment_date         DATE,
    exit_date               DATE,
    holding_period_years    FLOAT,
    key_risks               VARCHAR,
    action_required         VARCHAR,
    doc_status              VARCHAR,
    doc_summary             VARCHAR,

    -- Quality
    extraction_confidence   FLOAT,          -- overall extraction confidence estimate
    low_confidence_fields   ARRAY,          -- fields with low confidence
    pii_detected            BOOLEAN         DEFAULT FALSE,  -- TRUE if PII patterns detected

    extracted_at            TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_attributes PRIMARY KEY (attribute_id),
    CONSTRAINT uq_attributes UNIQUE (file_path, processing_version)
)
COMMENT = 'AI_EXTRACT results — infrastructure PE deal attributes per document version';

-- =============================================================================
-- TABLE: extraction_overrides — User-submitted manual corrections
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.extraction_overrides (
    override_id         VARCHAR         DEFAULT UUID_STRING()   NOT NULL,
    file_path           VARCHAR         NOT NULL,
    processing_version  INT             NOT NULL,
    field_name          VARCHAR         NOT NULL,
    original_value      VARCHAR,
    corrected_value     VARCHAR         NOT NULL,
    override_reason     VARCHAR,
    submitted_by        VARCHAR         DEFAULT CURRENT_USER(),
    submitted_at        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    approved_by         VARCHAR,
    approved_at         TIMESTAMP_NTZ,
    override_status     VARCHAR         DEFAULT 'PENDING', -- PENDING/APPROVED/REJECTED
    CONSTRAINT pk_overrides PRIMARY KEY (override_id)
)
COMMENT = 'User-submitted corrections to AI-extracted attributes — feeds quality improvement';

-- =============================================================================
-- STORED PROCEDURE: Parse pending documents (format-aware)
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.DATA.sp_parse_pending_documents()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
DECLARE
    parsed_count    INT DEFAULT 0;
    failed_count    INT DEFAULT 0;
    stage_prefix    VARCHAR;
BEGIN
    -- Lock PENDING records → PROCESSING
    UPDATE DEAL_INTEL.DATA.ingestion_registry
    SET ingestion_status   = 'PROCESSING',
        processing_started_at = CURRENT_TIMESTAMP(),
        processing_attempts   = processing_attempts + 1,
        error_stage           = NULL,
        last_error            = NULL,
        updated_at            = CURRENT_TIMESTAMP()
    WHERE ingestion_status = 'PENDING';

    -- ----------------------------------------------------------------
    -- Parse TIFF / JPEG / PNG — use OCR mode
    -- ----------------------------------------------------------------
    INSERT INTO DEAL_INTEL.DATA.parsed_documents (
        file_path, stage_name, file_format, processing_version,
        parse_mode, parse_result, page_count, raw_content,
        parse_status, parse_completed_at, parse_duration_ms
    )
    WITH ocr_batch AS (
        SELECT
            r.file_path, r.stage_name, r.file_format, r.processing_version,
            AI_PARSE_DOCUMENT(
                TO_FILE('@' || r.stage_name, r.file_path),
                {'mode': 'OCR'}
            ) AS parsed
        FROM DEAL_INTEL.DATA.ingestion_registry r
        WHERE r.ingestion_status = 'PROCESSING'
          AND r.file_format IN ('TIF', 'TIFF', 'JPG', 'JPEG', 'PNG')
          AND NOT EXISTS (
              SELECT 1 FROM DEAL_INTEL.DATA.parsed_documents p
              WHERE p.file_path = r.file_path AND p.processing_version = r.processing_version
          )
    )
    SELECT
        file_path, stage_name, file_format, processing_version,
        'OCR', parsed, 1, parsed:content::VARCHAR,
        'COMPLETE', CURRENT_TIMESTAMP(), 0
    FROM ocr_batch;

    -- ----------------------------------------------------------------
    -- Parse PDF / DOCX / PPTX / HTML / TXT — use LAYOUT mode
    -- ----------------------------------------------------------------
    INSERT INTO DEAL_INTEL.DATA.parsed_documents (
        file_path, stage_name, file_format, processing_version,
        parse_mode, parse_result, page_count, raw_content,
        parse_status, parse_completed_at, parse_duration_ms
    )
    WITH layout_batch AS (
        SELECT
            r.file_path, r.stage_name, r.file_format, r.processing_version,
            AI_PARSE_DOCUMENT(
                TO_FILE('@' || r.stage_name, r.file_path),
                {'mode': 'LAYOUT'}
            ) AS parsed
        FROM DEAL_INTEL.DATA.ingestion_registry r
        WHERE r.ingestion_status = 'PROCESSING'
          AND r.file_format IN ('PDF', 'DOCX', 'PPTX', 'HTML', 'TXT')
          AND NOT EXISTS (
              SELECT 1 FROM DEAL_INTEL.DATA.parsed_documents p
              WHERE p.file_path = r.file_path AND p.processing_version = r.processing_version
          )
    )
    SELECT
        file_path, stage_name, file_format, processing_version,
        'LAYOUT', parsed,
        COALESCE(parsed:metadata:pageCount::INT, 1),
        parsed:content::VARCHAR,
        'COMPLETE', CURRENT_TIMESTAMP(), 0
    FROM layout_batch;

    -- ----------------------------------------------------------------
    -- Flatten pages into document_pages table
    -- ----------------------------------------------------------------
    INSERT INTO DEAL_INTEL.DATA.document_pages (
        file_path, processing_version, page_index, page_content, total_pages,
        ir_file_id, source_folder, ir_policy_number, ir_claim_number
    )
    SELECT
        pd.file_path,
        pd.processing_version,
        -- For paginated: use page index; for images: page_index = 0
        CASE WHEN pd.parse_result:pages IS NOT NULL
             THEN p.value:index::INT
             ELSE 0
        END                         AS page_index,
        CASE WHEN pd.parse_result:pages IS NOT NULL
             THEN p.value:content::VARCHAR
             ELSE pd.raw_content
        END                         AS page_content,
        pd.page_count               AS total_pages,
        r.ir_file_id,
        r.source_folder,
        r.ir_policy_number,
        r.ir_claim_number
    FROM DEAL_INTEL.DATA.parsed_documents pd
    INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
        ON pd.file_path = r.file_path AND pd.processing_version = r.processing_version
    LEFT JOIN LATERAL FLATTEN(
        input => COALESCE(pd.parse_result:pages, ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('index', 0, 'content', pd.raw_content))),
        OUTER => TRUE
    ) p
    WHERE pd.parse_status = 'COMPLETE'
      AND NOT EXISTS (
          SELECT 1 FROM DEAL_INTEL.DATA.document_pages dp
          WHERE dp.file_path = pd.file_path AND dp.processing_version = pd.processing_version
      );

    -- ----------------------------------------------------------------
    -- Update content_hash on registry (change detection for next run)
    -- ----------------------------------------------------------------
    UPDATE DEAL_INTEL.DATA.ingestion_registry r
    SET content_hash  = SHA2(pd.raw_content, 256),
        updated_at    = CURRENT_TIMESTAMP()
    FROM DEAL_INTEL.DATA.parsed_documents pd
    WHERE r.file_path = pd.file_path
      AND r.processing_version = pd.processing_version
      AND pd.parse_status = 'COMPLETE';

    -- Log telemetry for parsed docs
    INSERT INTO DEAL_INTEL.TELEMETRY.pipeline_events (
        event_type, stage_name, file_path, source_folder, status,
        metadata
    )
    SELECT
        'PARSE_COMPLETE', 'PARSE', pd.file_path, r.source_folder, 'SUCCESS',
        OBJECT_CONSTRUCT(
            'parse_mode', pd.parse_mode,
            'page_count', pd.page_count,
            'file_format', pd.file_format
        )
    FROM DEAL_INTEL.DATA.parsed_documents pd
    INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
        ON pd.file_path = r.file_path AND pd.processing_version = r.processing_version
    WHERE pd.parse_status = 'COMPLETE';

    RETURN 'Parsing complete. Check parsed_documents for results.';
END;
$$;

-- =============================================================================
-- STORED PROCEDURE: Classify parsed documents
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.DATA.sp_classify_parsed_documents()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO DEAL_INTEL.DATA.classified_documents (
        file_path, processing_version, source_folder, ai_classification,
        primary_document_type, all_document_types, confidence_score,
        ir_document_type, classification_match, needs_review
    )
    SELECT
        pd.file_path,
        pd.processing_version,
        r.source_folder,
        -- Classify using first-page content
        AI_CLASSIFY(
            first_page.page_content,
            [
                'Submission Application',
                'Supplemental Application',
                'Financial Statement for Underwriting',
                'Loss History / Loss Run',
                'Quote / Indication',
                'Binder',
                'Declination Letter',
                'Policy Declarations Page',
                'Manuscript Endorsement',
                'Standard Endorsement',
                'Policy Form / Wording',
                'Coverage Summary',
                'Side Letter / DIC',
                'IC Presentation',
                'Claim Acknowledgment',
                'Adjuster / Examiner Report',
                'Reserve Worksheet',
                'Coverage Opinion / Coverage Letter',
                'Denial Letter',
                'Settlement Agreement',
                'Subrogation Notice',
                'Certificate of Insurance',
                'Surplus Lines Tax Filing',
                'Compliance Certificate',
                'Regulatory Filing',
                'Broker / Wholesale Correspondence',
                'Carrier Correspondence',
                'Insured Correspondence',
                'Legal Notice / Subpoena',
                'Reinsurance Certificate',
                'Treaty / Facultative Placement',
                'Bordereau / Premium Report',
                'Invoice / Premium Statement',
                'Commission Statement',
                'Cancellation Notice',
                'Reinstatement Notice',
                'Premium Audit Worksheet',
                'Actuarial Report / Loss Development',
                'Risk Assessment / Engineering Report',
                'Third-Party Report',
                'Medical Record / Report',
                'Police / Fire / Incident Report',
                'Appraisal / Estimate',
                'Photo / Site Image'
            ],
            {'output_mode': 'multi'}
        )                                           AS ai_classification,
        -- Primary type = first label (highest confidence)
        ai_classification:labels[0]::VARCHAR        AS primary_document_type,
        ai_classification:labels                    AS all_document_types,
        -- Confidence approximation (AI_CLASSIFY doesn't return scores directly;
        -- we use multi-label count as proxy: fewer labels = more confident)
        CASE WHEN ARRAY_SIZE(ai_classification:labels) = 1 THEN 0.95
             WHEN ARRAY_SIZE(ai_classification:labels) = 2 THEN 0.80
             WHEN ARRAY_SIZE(ai_classification:labels) = 3 THEN 0.65
             ELSE 0.50
        END                                         AS confidence_score,
        r.ir_document_type,
        -- Check if AI classification matches IR native type (approximate)
        CONTAINS(UPPER(ai_classification:labels::VARCHAR), UPPER(r.ir_document_type))
                                                    AS classification_match,
        -- Flag for review if confidence below threshold
        (ARRAY_SIZE(ai_classification:labels) >= 3) AS needs_review
    FROM DEAL_INTEL.DATA.parsed_documents pd
    INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
        ON pd.file_path = r.file_path AND pd.processing_version = r.processing_version
    -- Use first page content for classification
    INNER JOIN (
        SELECT file_path, processing_version, page_content
        FROM DEAL_INTEL.DATA.document_pages
        WHERE page_index = 0
    ) first_page ON first_page.file_path = pd.file_path
              AND first_page.processing_version = pd.processing_version
    WHERE pd.parse_status = 'COMPLETE'
      AND r.ingestion_status = 'PROCESSING'
      AND NOT EXISTS (
          SELECT 1 FROM DEAL_INTEL.DATA.classified_documents cd
          WHERE cd.file_path = pd.file_path AND cd.processing_version = pd.processing_version
      );

    -- Log telemetry
    INSERT INTO DEAL_INTEL.TELEMETRY.pipeline_events (
        event_type, stage_name, file_path, source_folder, status, metadata
    )
    SELECT
        'CLASSIFY_COMPLETE', 'CLASSIFY', cd.file_path, r.source_folder, 'SUCCESS',
        OBJECT_CONSTRUCT(
            'primary_type', cd.primary_document_type,
            'confidence', cd.confidence_score,
            'needs_review', cd.needs_review
        )
    FROM DEAL_INTEL.DATA.classified_documents cd
    INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
        ON cd.file_path = r.file_path AND cd.processing_version = r.processing_version
    WHERE r.ingestion_status = 'PROCESSING';

    RETURN 'Classification complete.';
END;
$$;

-- =============================================================================
-- STORED PROCEDURE: Extract key attributes (infrastructure PE deal schema)
-- =============================================================================

CREATE OR REPLACE PROCEDURE DEAL_INTEL.DATA.sp_extract_document_attributes()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO DEAL_INTEL.DATA.document_attributes (
        file_path, processing_version, extracted_attributes,
        document_date, target_company, deal_name, sponsor_name,
        co_investors, sector, deal_stage, fund_name, geography,
        enterprise_value, equity_check, net_debt,
        target_irr, target_moic, investment_date, exit_date,
        holding_period_years, key_risks, action_required,
        doc_status, doc_summary
    )
    WITH extraction_cte AS (
        SELECT
            pd.file_path,
            pd.processing_version,
            AI_EXTRACT(
                pd.raw_content,
                {
                    'document_date':         'Date the document was created, issued, or effective',
                    'target_company':        'Target company or portfolio company name being acquired, invested in, or reported on',
                    'deal_name':             'Deal or project code name used internally',
                    'sponsor_name':          'Lead sponsor or GP firm name (e.g. DealIntelligence)',
                    'co_investors':          'Co-investors, co-lead, or LP co-invest partners',
                    'sector':                'Infrastructure sector: Digital Infrastructure, Transportation & Logistics, Energy Transition, Water & Environmental, Social Infrastructure, Communications, Conventional Power, or Multi-Sector',
                    'deal_stage':            'Current deal stage: Sourcing, Due Diligence, IC Review, Closing, Portfolio, or Exited',
                    'fund_name':             'Fund vehicle name (e.g. DealIntelligence Infrastructure Fund V)',
                    'geography':             'Primary geography of the target asset or company (country or region)',
                    'enterprise_value':      'Total enterprise value or TEV of the target (dollar amount)',
                    'equity_check':          'Equity investment amount or equity check size',
                    'net_debt':              'Net debt amount at the target level',
                    'target_irr':            'Target or projected gross/net IRR percentage',
                    'target_moic':           'Target or projected gross/net MOIC multiple',
                    'investment_date':       'Date of investment closing or expected closing',
                    'exit_date':             'Date of exit or expected exit',
                    'holding_period_years':  'Expected or actual holding period in years',
                    'key_risks':             'Key investment risks, mitigants, or watchlist items mentioned',
                    'action_required':       'Required actions, next steps, approvals needed, or deadlines',
                    'doc_status':            'Document or deal status: active, draft, final, approved, pending IC, closed, exited',
                    'doc_summary':           'Two to three sentence summary of the document purpose and key deal or portfolio information'
                }
            ) AS extracted_attributes
        FROM DEAL_INTEL.DATA.parsed_documents pd
        INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
            ON pd.file_path = r.file_path AND pd.processing_version = r.processing_version
        WHERE pd.parse_status = 'COMPLETE'
          AND r.ingestion_status = 'PROCESSING'
          AND NOT EXISTS (
              SELECT 1 FROM DEAL_INTEL.DATA.document_attributes da
              WHERE da.file_path = pd.file_path AND da.processing_version = pd.processing_version
          )
    )
    SELECT
        file_path,
        processing_version,
        extracted_attributes,
        TRY_TO_DATE(extracted_attributes:response:document_date::VARCHAR),
        extracted_attributes:response:target_company::VARCHAR,
        extracted_attributes:response:deal_name::VARCHAR,
        extracted_attributes:response:sponsor_name::VARCHAR,
        extracted_attributes:response:co_investors::VARCHAR,
        extracted_attributes:response:sector::VARCHAR,
        extracted_attributes:response:deal_stage::VARCHAR,
        extracted_attributes:response:fund_name::VARCHAR,
        extracted_attributes:response:geography::VARCHAR,
        extracted_attributes:response:enterprise_value::VARCHAR,
        extracted_attributes:response:equity_check::VARCHAR,
        extracted_attributes:response:net_debt::VARCHAR,
        extracted_attributes:response:target_irr::VARCHAR,
        extracted_attributes:response:target_moic::VARCHAR,
        TRY_TO_DATE(extracted_attributes:response:investment_date::VARCHAR),
        TRY_TO_DATE(extracted_attributes:response:exit_date::VARCHAR),
        TRY_TO_DOUBLE(extracted_attributes:response:holding_period_years::VARCHAR),
        extracted_attributes:response:key_risks::VARCHAR,
        extracted_attributes:response:action_required::VARCHAR,
        extracted_attributes:response:doc_status::VARCHAR,
        extracted_attributes:response:doc_summary::VARCHAR
    FROM extraction_cte;

    -- Mark registry as COMPLETE
    UPDATE DEAL_INTEL.DATA.ingestion_registry r
    SET ingestion_status           = 'COMPLETE',
        processing_completed_at    = CURRENT_TIMESTAMP(),
        updated_at                 = CURRENT_TIMESTAMP()
    WHERE ingestion_status = 'PROCESSING'
      AND EXISTS (
          SELECT 1 FROM DEAL_INTEL.DATA.document_attributes da
          WHERE da.file_path = r.file_path AND da.processing_version = r.processing_version
      );

    -- Log completion telemetry
    INSERT INTO DEAL_INTEL.TELEMETRY.pipeline_events (
        event_type, stage_name, file_path, source_folder, status, metadata
    )
    SELECT
        'EXTRACT_COMPLETE', 'EXTRACT', da.file_path, r.source_folder, 'SUCCESS',
        OBJECT_CONSTRUCT(
            'sector', da.sector,
            'deal_stage', da.deal_stage,
            'has_target_company', (da.target_company IS NOT NULL),
            'has_enterprise_value', (da.enterprise_value IS NOT NULL)
        )
    FROM DEAL_INTEL.DATA.document_attributes da
    INNER JOIN DEAL_INTEL.DATA.ingestion_registry r
        ON da.file_path = r.file_path AND da.processing_version = r.processing_version
    WHERE r.ingestion_status = 'COMPLETE';

    RETURN 'Attribute extraction complete.';
END;
$$;

-- =============================================================================
-- DYNAMIC TABLE: overrides_pivoted — pre-pivot overrides for incremental join
-- =============================================================================
-- Pre-pivots extraction_overrides into one row per (file_path, processing_version)
-- so the catalog DT can use a single LEFT JOIN instead of 10 filtered subqueries.

CREATE OR REPLACE DYNAMIC TABLE DEAL_INTEL.DATA.overrides_pivoted
    TARGET_LAG = '1 hour'
    WAREHOUSE  = DEAL_INTEL_WH
    COMMENT    = 'Pre-pivoted extraction overrides — one row per (file_path, version) for incremental join'
AS
SELECT
    file_path,
    processing_version,
    MAX(CASE WHEN field_name = 'document_date'     THEN corrected_value END) AS document_date_override,
    MAX(CASE WHEN field_name = 'target_company'    THEN corrected_value END) AS target_company_override,
    MAX(CASE WHEN field_name = 'deal_name'         THEN corrected_value END) AS deal_name_override,
    MAX(CASE WHEN field_name = 'sector'            THEN corrected_value END) AS sector_override,
    MAX(CASE WHEN field_name = 'deal_stage'        THEN corrected_value END) AS deal_stage_override,
    MAX(CASE WHEN field_name = 'fund_name'         THEN corrected_value END) AS fund_name_override,
    MAX(CASE WHEN field_name = 'enterprise_value'  THEN corrected_value END) AS enterprise_value_override,
    MAX(CASE WHEN field_name = 'doc_status'        THEN corrected_value END) AS doc_status_override
FROM DEAL_INTEL.ADMIN.extraction_overrides
WHERE override_status = 'APPROVED'
GROUP BY file_path, processing_version;

-- =============================================================================
-- DYNAMIC TABLE: document_catalog — final unified view (INCREMENTAL refresh)
-- =============================================================================
-- Uses QUALIFY ROW_NUMBER() instead of correlated subquery to enable incremental
-- refresh, which is required for Cortex Search Service change tracking.

CREATE OR REPLACE DYNAMIC TABLE DEAL_INTEL.DATA.document_catalog
    TARGET_LAG    = '1 hour'
    REFRESH_MODE  = INCREMENTAL
    WAREHOUSE     = DEAL_INTEL_WH
    COMMENT       = 'Unified document catalog — latest version of each document with all extracted attributes and IR metadata'
AS
SELECT
    r.registry_id,
    r.file_path,
    r.stage_name,
    r.file_format,
    r.processing_version,
    r.ir_file_id,
    r.source_folder,
    r.ir_policy_number,
    r.ir_claim_number,
    r.ir_assigned_to,
    r.ir_date_created,
    cd.primary_document_type        AS document_type,
    cd.all_document_types,
    cd.confidence_score             AS classification_confidence,
    cd.needs_review,
    cd.ir_document_type,
    cd.classification_match,
    COALESCE(ov.document_date_override, da.document_date::VARCHAR)::DATE  AS document_date,
    COALESCE(ov.target_company_override, da.target_company)              AS target_company,
    COALESCE(ov.deal_name_override, da.deal_name)                        AS deal_name,
    da.sponsor_name,
    da.co_investors,
    COALESCE(ov.sector_override, da.sector)                              AS sector,
    COALESCE(ov.deal_stage_override, da.deal_stage)                      AS deal_stage,
    COALESCE(ov.fund_name_override, da.fund_name)                        AS fund_name,
    da.geography,
    COALESCE(ov.enterprise_value_override, da.enterprise_value)          AS enterprise_value,
    da.equity_check,
    da.net_debt,
    da.target_irr,
    da.target_moic,
    da.investment_date,
    da.exit_date,
    da.holding_period_years,
    da.key_risks,
    da.action_required,
    COALESCE(ov.doc_status_override, da.doc_status)                      AS doc_status,
    da.doc_summary,
    pd.raw_content                  AS full_text,
    pd.page_count,
    pd.parse_mode,
    r.first_seen_at                 AS upload_timestamp,
    r.first_seen_at,
    r.processing_completed_at,
    r.ingestion_status
FROM DEAL_INTEL.DATA.ingestion_registry r
INNER JOIN DEAL_INTEL.DATA.parsed_documents pd
    ON r.file_path = pd.file_path AND r.processing_version = pd.processing_version
INNER JOIN DEAL_INTEL.DATA.classified_documents cd
    ON r.file_path = cd.file_path AND r.processing_version = cd.processing_version
INNER JOIN DEAL_INTEL.DATA.document_attributes da
    ON r.file_path = da.file_path AND r.processing_version = da.processing_version
LEFT JOIN DEAL_INTEL.DATA.overrides_pivoted ov
    ON r.file_path = ov.file_path AND r.processing_version = ov.processing_version
WHERE r.ingestion_status = 'COMPLETE'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY r.file_path
    ORDER BY r.processing_version DESC
) = 1;
