-- =============================================================================
-- DEAL_INTEL: Intelligence Services
-- File: sql/05_intelligence.sql
-- Description: Cortex Search, Semantic View, Cortex Agent
-- Run as: DEAL_INTEL_ADMIN after 04_telemetry.sql
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA SERVICES;
USE WAREHOUSE DEAL_INTEL_WH;

-- =============================================================================
-- CORTEX SEARCH SERVICE: Hybrid semantic + keyword retrieval
-- =============================================================================
-- Indexes document_catalog for document-level search with structured metadata
-- filters, and document_pages for granular per-page RAG retrieval.

-- Document-level search (full catalog, with all filterable attributes)
CREATE OR REPLACE CORTEX SEARCH SERVICE DEAL_INTEL.SERVICES.deal_search_svc
    ON full_text
    ATTRIBUTES  document_type,
                doc_status,
                source_folder,
                sector,
                deal_stage,
                fund_name,
                target_company,
                geography,
                file_format
    WAREHOUSE   = DEAL_INTEL_WH
    TARGET_LAG  = '1 hour'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'Primary document search — hybrid vector+keyword, filterable by sector/deal_stage/fund'
AS (
    SELECT
        dc.file_path,
        dc.ir_file_id,
        dc.source_folder,
        dc.document_type,
        dc.all_document_types,
        dc.classification_confidence,
        dc.target_company,
        dc.deal_name,
        dc.sponsor_name,
        dc.co_investors,
        dc.sector,
        dc.deal_stage,
        dc.fund_name,
        dc.geography,
        dc.enterprise_value,
        dc.equity_check,
        dc.target_irr,
        dc.target_moic,
        dc.investment_date::VARCHAR           AS investment_date,
        dc.exit_date::VARCHAR                 AS exit_date,
        dc.key_risks,
        dc.action_required,
        dc.doc_status,
        dc.doc_summary,
        dc.file_format,
        dc.page_count,
        dc.processing_completed_at::VARCHAR   AS indexed_at,
        dc.full_text
    FROM DEAL_INTEL.DATA.document_catalog dc
);

-- Page-level search (granular retrieval for RAG — better precision on long docs)
CREATE OR REPLACE CORTEX SEARCH SERVICE DEAL_INTEL.SERVICES.deal_page_search_svc
    ON page_content
    ATTRIBUTES  source_folder, file_path
    WAREHOUSE   = DEAL_INTEL_WH
    TARGET_LAG  = '1 hour'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'Page-level search for RAG — granular retrieval from multi-page documents'
AS (
    SELECT
        dp.file_path,
        dp.processing_version,
        dp.page_index,
        dp.total_pages,
        dp.source_folder,
        dp.page_content
    FROM DEAL_INTEL.DATA.document_pages dp
);

-- Grant search to user role
GRANT USAGE ON CORTEX SEARCH SERVICE DEAL_INTEL.SERVICES.deal_search_svc      TO ROLE DEAL_INTEL_USER;
GRANT USAGE ON CORTEX SEARCH SERVICE DEAL_INTEL.SERVICES.deal_page_search_svc TO ROLE DEAL_INTEL_USER;

-- =============================================================================
-- SEMANTIC VIEW: Cortex Analyst — natural language → SQL for deal analytics
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW DEAL_INTEL.SERVICES.deal_analytics_sv

  TABLES (
    doc_catalog AS DEAL_INTEL.DATA.document_catalog
  )

  DIMENSIONS (
    doc_catalog.file_path AS file_path
      COMMENT = 'Full path to the source document file on stage',
    doc_catalog.ir_file_id AS ir_file_id
      COMMENT = 'Unique file identifier from source system',
    doc_catalog.source_folder AS source_folder
      COMMENT = 'Upload folder: Deal Sourcing, Due Diligence, Transaction, Portfolio, IR, Compliance',
    doc_catalog.document_type AS document_type
      COMMENT = 'AI-classified document type: Investment Memo, Term Sheet, IC Presentation, DD Report, Board Deck, LP Report, etc.',
    doc_catalog.file_format AS file_format
      COMMENT = 'Source file format: PDF, DOCX, XLSX, PPTX, TXT',
    doc_catalog.needs_review AS needs_review
      COMMENT = 'True if classification confidence is below threshold',
    doc_catalog.target_company AS target_company
      COMMENT = 'Target company or portfolio company name',
    doc_catalog.deal_name AS deal_name
      COMMENT = 'Internal deal or project code name',
    doc_catalog.sponsor_name AS sponsor_name
      COMMENT = 'Lead sponsor or GP firm name',
    doc_catalog.sector AS sector
      COMMENT = 'Infrastructure sector: Digital Infrastructure, Transportation & Logistics, Energy Transition, Water & Environmental, Social Infrastructure, Communications, Conventional Power',
    doc_catalog.deal_stage AS deal_stage
      COMMENT = 'Deal lifecycle stage: Sourcing, Due Diligence, IC Review, Closing, Portfolio, Exited',
    doc_catalog.fund_name AS fund_name
      COMMENT = 'Fund vehicle name (e.g. DealIntelligence Infrastructure Fund V)',
    doc_catalog.geography AS geography
      COMMENT = 'Primary geography of the target asset (country or region)',
    doc_catalog.doc_status AS doc_status
      COMMENT = 'Document status: active, draft, final, approved, pending IC, closed, exited',
    doc_catalog.investment_date AS investment_date
      COMMENT = 'Date of investment closing',
    doc_catalog.exit_date AS exit_date
      COMMENT = 'Date of exit or expected exit',
    doc_catalog.upload_timestamp AS upload_timestamp
      COMMENT = 'When the document was first seen in the ingestion stage'
  )

  METRICS (
    doc_catalog.document_count AS COUNT(*)
      COMMENT = 'Total number of documents',
    doc_catalog.avg_confidence AS AVG(classification_confidence)
      COMMENT = 'Average AI classification confidence score',
    doc_catalog.total_pages AS SUM(page_count)
      COMMENT = 'Total number of pages across documents'
  )

  COMMENT = 'Analytics model for infrastructure PE deal documents — natural language to SQL';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW DEAL_INTEL.SERVICES.deal_analytics_sv TO ROLE DEAL_INTEL_USER;

-- =============================================================================
-- CORTEX AGENT: Routes between Search and Analyst based on question intent
-- =============================================================================

CREATE OR REPLACE AGENT DEAL_INTEL.SERVICES.deal_intelligence_agent
  COMMENT = 'Infrastructure PE deal intelligence agent'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-sonnet-4-5

  orchestration:
    budget:
      seconds: 120
      tokens: 32000

  instructions:
    response: "You are an infrastructure private equity deal intelligence assistant for DealIntelligence. Always cite file_path when referencing documents. Format citations as: [file_path]. This is informational retrieval, not investment advice."
    orchestration: "Use deal_search for questions seeking specific documents, deal terms, due diligence findings, or document content. Use deal_analytics for questions requiring aggregation, counting, statistics, or trend analysis (how many deals, total equity deployed, breakdown by sector, average IRR). Use both when a question needs retrieval AND analytics."
    sample_questions:
      - question: "What are the key risks identified in the data center acquisition DD report?"
      - question: "How many deals do we have by sector and deal stage?"
      - question: "Find all IC presentations for Digital Infrastructure investments"

  tools:
    - tool_spec:
        type: "cortex_search"
        name: "deal_search"
        description: "Searches infrastructure PE deal documents including investment memos, IC presentations, DD reports, term sheets, board decks, and LP reports. Use for finding specific documents, deal terms, risk factors, and investment thesis details."
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "deal_analytics"
        description: "Analyzes the deal document portfolio with SQL queries. Use for counting documents, aggregating by sector or deal stage, fund-level statistics, and portfolio analytics."

  tool_resources:
    deal_search:
      search_service: "DEAL_INTEL.SERVICES.DEAL_SEARCH_SVC"
      max_results: 10
    deal_analytics:
      semantic_view: "DEAL_INTEL.SERVICES.DEAL_ANALYTICS_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "DEAL_INTEL_QUERY_WH"
  $$;

GRANT USAGE ON AGENT DEAL_INTEL.SERVICES.deal_intelligence_agent TO ROLE DEAL_INTEL_USER;
