-- =============================================================================
-- DEAL_INTEL: Foundation DDL
-- File: sql/01_foundation.sql
-- Description: Database, schemas, warehouses, stages, roles, and RBAC setup
-- Run as: DEAL_INTEL_ADMIN (owns the database after 00_provision_account.sql)
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- DATABASE and SCHEMAS
-- =============================================================================

CREATE DATABASE IF NOT EXISTS DEAL_INTEL
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'Document Intelligence Pipeline — Infrastructure Investments';

-- Core pipeline tables (raw, parsed, classified, extracted, catalog)
CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.DATA
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'Pipeline output tables — source of truth for all document data';

-- AI services: agent, cortex search, semantic view
CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.SERVICES
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'AI services — agent, search, semantic view';

-- Telemetry: event logs, metrics, cost tracking
CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.TELEMETRY
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Pipeline telemetry, event logs, and metric views';

-- Admin: config, reprocess queue, feedback, overrides
CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.ADMIN
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Admin configuration, queues, feedback, and audit';

-- App: restricted views with RBAC applied — all app queries go through here
CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.APP
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'App-facing views with row-level security enforced';

CREATE SCHEMA IF NOT EXISTS DEAL_INTEL.APP_SERVICE
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'SPCS application service deployment target';

-- =============================================================================
-- WAREHOUSES
-- =============================================================================

-- Pipeline processing (AI functions, tasks, dynamic tables)
CREATE WAREHOUSE IF NOT EXISTS DEAL_INTEL_WH
    WAREHOUSE_SIZE    = 'MEDIUM'
    AUTO_SUSPEND      = 300
    AUTO_RESUME       = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 1800
    COMMENT = 'Document intelligence pipeline processing (AI functions, tasks)';

-- User queries (search, analytics, app) — small and cost-efficient
CREATE WAREHOUSE IF NOT EXISTS DEAL_INTEL_QUERY_WH
    WAREHOUSE_SIZE    = 'XSMALL'
    AUTO_SUSPEND      = 60
    AUTO_RESUME       = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300
    COMMENT = 'User query warehouse — search, analytics, Next.js app';

-- =============================================================================
-- STAGES
-- =============================================================================

-- Primary source: source system documents exported via REST API
CREATE STAGE IF NOT EXISTS DEAL_INTEL.DATA.deal_documents_stage
    DIRECTORY = (ENABLE = TRUE, AUTO_REFRESH = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'source system document exports — TIFF, PDF, DOCX, JPEG, PNG, HTML, TXT';

-- Sample/demo documents for testing
CREATE STAGE IF NOT EXISTS DEAL_INTEL.DATA.sample_stage
    DIRECTORY = (ENABLE = TRUE, AUTO_REFRESH = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Sample documents for testing and demonstration';

-- Metadata sidecars (JSON files paired with each document)
CREATE STAGE IF NOT EXISTS DEAL_INTEL.DATA.metadata_stage
    DIRECTORY = (ENABLE = TRUE, AUTO_REFRESH = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'source system metadata JSON sidecars';

-- =============================================================================
-- ROLES
-- =============================================================================

-- Roles are created by 00_provision_account.sql. Ensure hierarchy is correct.
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DEAL_INTEL_PIPELINE
    COMMENT = 'Pipeline service role — reads stage, writes pipeline tables, emits telemetry';
CREATE ROLE IF NOT EXISTS DEAL_INTEL_USER
    COMMENT = 'Standard user role — search, analytics, document browser';

-- NOTE: DEAL_INTEL_PIPELINE must NOT be granted to DEAL_INTEL_ADMIN (RAP bypass issue)
-- GRANT ROLE DEAL_INTEL_PIPELINE TO ROLE DEAL_INTEL_ADMIN;
GRANT ROLE DEAL_INTEL_USER     TO ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- ROLE GRANTS: DEAL_INTEL_PIPELINE
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;

GRANT USAGE ON DATABASE DEAL_INTEL                     TO ROLE DEAL_INTEL_PIPELINE;
GRANT USAGE ON WAREHOUSE DEAL_INTEL_WH                 TO ROLE DEAL_INTEL_PIPELINE;
GRANT USAGE ON SCHEMA DEAL_INTEL.DATA                  TO ROLE DEAL_INTEL_PIPELINE;
GRANT USAGE ON SCHEMA DEAL_INTEL.SERVICES              TO ROLE DEAL_INTEL_PIPELINE;
GRANT USAGE ON SCHEMA DEAL_INTEL.TELEMETRY             TO ROLE DEAL_INTEL_PIPELINE;
GRANT USAGE ON SCHEMA DEAL_INTEL.ADMIN                 TO ROLE DEAL_INTEL_PIPELINE;

GRANT READ ON STAGE DEAL_INTEL.DATA.deal_documents_stage   TO ROLE DEAL_INTEL_PIPELINE;
GRANT READ ON STAGE DEAL_INTEL.DATA.sample_stage       TO ROLE DEAL_INTEL_PIPELINE;
GRANT READ ON STAGE DEAL_INTEL.DATA.metadata_stage     TO ROLE DEAL_INTEL_PIPELINE;

-- Pipeline can create and modify all objects in its schemas
GRANT ALL PRIVILEGES ON ALL TABLES     IN SCHEMA DEAL_INTEL.DATA      TO ROLE DEAL_INTEL_PIPELINE;
GRANT ALL PRIVILEGES ON ALL TABLES     IN SCHEMA DEAL_INTEL.TELEMETRY TO ROLE DEAL_INTEL_PIPELINE;
GRANT ALL PRIVILEGES ON ALL TABLES     IN SCHEMA DEAL_INTEL.ADMIN     TO ROLE DEAL_INTEL_PIPELINE;
GRANT ALL PRIVILEGES ON FUTURE TABLES  IN SCHEMA DEAL_INTEL.DATA      TO ROLE DEAL_INTEL_PIPELINE;
GRANT ALL PRIVILEGES ON FUTURE TABLES  IN SCHEMA DEAL_INTEL.TELEMETRY TO ROLE DEAL_INTEL_PIPELINE;
GRANT ALL PRIVILEGES ON FUTURE TABLES  IN SCHEMA DEAL_INTEL.ADMIN     TO ROLE DEAL_INTEL_PIPELINE;

GRANT CREATE TABLE    ON SCHEMA DEAL_INTEL.DATA      TO ROLE DEAL_INTEL_PIPELINE;
GRANT CREATE TABLE    ON SCHEMA DEAL_INTEL.TELEMETRY TO ROLE DEAL_INTEL_PIPELINE;
GRANT CREATE TABLE    ON SCHEMA DEAL_INTEL.ADMIN     TO ROLE DEAL_INTEL_PIPELINE;
GRANT CREATE DYNAMIC TABLE ON SCHEMA DEAL_INTEL.DATA   TO ROLE DEAL_INTEL_PIPELINE;
GRANT CREATE TASK     ON SCHEMA DEAL_INTEL.DATA      TO ROLE DEAL_INTEL_PIPELINE;
GRANT CREATE STREAM   ON SCHEMA DEAL_INTEL.DATA      TO ROLE DEAL_INTEL_PIPELINE;
GRANT EXECUTE TASK    ON ACCOUNT                    TO ROLE DEAL_INTEL_PIPELINE;

-- Cortex AI functions (SNOWFLAKE.CORTEX_USER)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DEAL_INTEL_PIPELINE;

-- =============================================================================
-- ROLE GRANTS: DEAL_INTEL_USER
-- =============================================================================

GRANT USAGE  ON DATABASE DEAL_INTEL                 TO ROLE DEAL_INTEL_USER;
GRANT USAGE  ON WAREHOUSE DEAL_INTEL_QUERY_WH       TO ROLE DEAL_INTEL_USER;
GRANT USAGE  ON SCHEMA DEAL_INTEL.APP               TO ROLE DEAL_INTEL_USER;

GRANT SELECT ON ALL VIEWS IN SCHEMA DEAL_INTEL.APP  TO ROLE DEAL_INTEL_USER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA DEAL_INTEL.APP TO ROLE DEAL_INTEL_USER;

-- Users can write feedback and saved searches (tables created in 06_admin.sql)
-- Object-level grants moved to 08_post_deploy_grants.sql
GRANT USAGE  ON SCHEMA DEAL_INTEL.ADMIN             TO ROLE DEAL_INTEL_USER;

-- Cortex services for search and analyst
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DEAL_INTEL_USER;

-- =============================================================================
-- ROLE GRANTS: DEAL_INTEL_ADMIN
-- =============================================================================

-- DEAL_INTEL_ADMIN owns the database — no explicit grants needed on owned objects.
-- Grant Cortex and task execution (already done in 00_provision but safe to repeat).
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- ROW ACCESS POLICY: Folder-level security
-- Applied to APP schema views so users only see their authorized folders
-- =============================================================================

USE SCHEMA DEAL_INTEL.DATA;
USE WAREHOUSE DEAL_INTEL_QUERY_WH;

CREATE OR REPLACE ROW ACCESS POLICY deal_intel_folder_policy
    AS (source_folder VARCHAR) RETURNS BOOLEAN ->
    CASE
        WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_ADMIN')    THEN TRUE
        WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_USER')     THEN TRUE
        WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') THEN TRUE
        ELSE FALSE
    END;

-- Masking policy for PII fields
CREATE OR REPLACE MASKING POLICY deal_intel_pii_mask
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_ADMIN') THEN val
        WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_USER')  THEN val
        ELSE '***MASKED***'
    END;

COMMENT ON MASKING POLICY deal_intel_pii_mask IS 'Masks PII fields (SSN, DOB, medical) for non-Claims, non-Admin roles';
