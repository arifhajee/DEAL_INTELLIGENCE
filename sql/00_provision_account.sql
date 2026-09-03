-- =============================================================================
-- DEAL_INTEL: Account Provisioning (One-Time Setup)
-- File: sql/00_provision_account.sql
--
-- PURPOSE:
--   Creates ALL infrastructure and roles needed to deploy and run DealIntel.
--   After this script runs, DEPLOY_USER can do everything with just the
--   DEAL_INTEL_ADMIN role — no SYSADMIN/ACCOUNTADMIN needed again.
--
-- WHO RUNS THIS:
--   A customer DBA with ACCOUNTADMIN (or delegated SECURITYADMIN + SYSADMIN).
--   This is a ONE-TIME setup per account.
--
-- WHAT THIS CREATES:
--   Infrastructure:
--     - DEAL_INTEL database + schemas (DATA, SERVICES, TELEMETRY, ADMIN, APP, APP_SERVICE)
--     - DEAL_INTEL_QUERY_WH warehouse (app queries)
--     - DEAL_INTEL_WH warehouse (pipeline processing)
--     - DEAL_INTEL_POOL compute pool (SPCS containers)
--     - DEAL_INTEL_EGRESS_EAI external access integration
--
--   Roles:
--     - DEAL_INTEL_ADMIN     — owns everything, deploys, administers
--     - DEAL_INTEL_PIPELINE  — runs tasks, writes tables, calls Cortex
--     - DEAL_INTEL_USER      — standard read access, search, analytics
--
-- CONFIGURATION:
--   Edit the variables below to match your environment.
-- =============================================================================

-- Configuration
SET app_db         = 'DEAL_INTEL';
SET pipeline_wh    = 'DEAL_INTEL_WH';
SET query_wh       = 'DEAL_INTEL_QUERY_WH';
SET compute_pool   = 'DEAL_INTEL_POOL';
SET deploy_user    = 'JOHN';

-- =============================================================================
-- STEP 1: ACCOUNTADMIN — Cortex AI access
-- =============================================================================

USE ROLE ACCOUNTADMIN;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;

-- =============================================================================
-- STEP 2: SYSADMIN — Create infrastructure
-- =============================================================================

USE ROLE SYSADMIN;

-- Database
CREATE DATABASE IF NOT EXISTS IDENTIFIER($app_db)
    COMMENT = 'DealIntel — pipeline data, admin config, and SPCS app service';
USE DATABASE IDENTIFIER($app_db);
CREATE SCHEMA IF NOT EXISTS DATA;
CREATE SCHEMA IF NOT EXISTS SERVICES;
CREATE SCHEMA IF NOT EXISTS TELEMETRY;
CREATE SCHEMA IF NOT EXISTS ADMIN;
CREATE SCHEMA IF NOT EXISTS APP;
CREATE SCHEMA IF NOT EXISTS APP_SERVICE;

-- Warehouses
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($pipeline_wh)
    WAREHOUSE_SIZE      = 'MEDIUM'
    AUTO_SUSPEND        = 120
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DealIntel pipeline processing — parsing, classification, extraction';

CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($query_wh)
    WAREHOUSE_SIZE      = 'XSMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DealIntel application queries — user-facing, low-latency';

-- Compute Pool (SPCS)
CREATE COMPUTE POOL IF NOT EXISTS IDENTIFIER($compute_pool)
    MIN_NODES         = 1
    MAX_NODES         = 1
    INSTANCE_FAMILY   = CPU_X64_S
    AUTO_SUSPEND_SECS = 300
    AUTO_RESUME       = TRUE
    COMMENT = 'DealIntel SPCS container pool — app service + build jobs';

-- Network Rule + External Access Integration
CREATE OR REPLACE NETWORK RULE DEAL_INTEL_EGRESS_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('0.0.0.0:443', '0.0.0.0:80')
    COMMENT = 'DealIntel egress — npm install during build + runtime API calls';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DEAL_INTEL_EGRESS_EAI
    ALLOWED_NETWORK_RULES = (DEAL_INTEL_EGRESS_RULE)
    ENABLED = TRUE
    COMMENT = 'Dedicated EAI for DealIntel app deployment and runtime';

-- =============================================================================
-- STEP 3: SECURITYADMIN — Create roles and hierarchy
-- =============================================================================

USE ROLE SECURITYADMIN;

-- Application roles (no DEAL_INTEL_DEPLOY — DEAL_INTEL_ADMIN does everything)
CREATE ROLE IF NOT EXISTS DEAL_INTEL_USER
    COMMENT = 'Standard user — search, analytics, document browser';

CREATE ROLE IF NOT EXISTS DEAL_INTEL_PIPELINE
    COMMENT = 'Pipeline service role — runs tasks, writes pipeline tables, calls Cortex AI';

CREATE ROLE IF NOT EXISTS DEAL_INTEL_ADMIN
    COMMENT = 'Admin/deploy role — owns database, deploys app, manages pipeline and users';

-- Role hierarchy: USER + PIPELINE → ADMIN → SYSADMIN
GRANT ROLE DEAL_INTEL_USER     TO ROLE DEAL_INTEL_ADMIN;
-- NOTE: DEAL_INTEL_PIPELINE must NOT be granted to DEAL_INTEL_ADMIN (RAP bypass issue)
-- GRANT ROLE DEAL_INTEL_PIPELINE TO ROLE DEAL_INTEL_ADMIN;
GRANT ROLE DEAL_INTEL_ADMIN    TO ROLE SYSADMIN;

-- Account-level privileges for DEAL_INTEL_ADMIN
GRANT MANAGE CALLER GRANTS    ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
GRANT BIND SERVICE ENDPOINT   ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
GRANT EXECUTE TASK            ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;

-- These require ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
GRANT CREATE INTEGRATION      ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
GRANT CREATE DATABASE         ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
GRANT CREATE WAREHOUSE        ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
GRANT CREATE COMPUTE POOL     ON ACCOUNT TO ROLE DEAL_INTEL_ADMIN;
USE ROLE SECURITYADMIN;

-- =============================================================================
-- STEP 4: SYSADMIN — Transfer ownership to DEAL_INTEL_ADMIN
-- =============================================================================

USE ROLE SYSADMIN;

-- Database + schemas ownership
GRANT OWNERSHIP ON DATABASE IDENTIFIER($app_db) TO ROLE DEAL_INTEL_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE IDENTIFIER($app_db) TO ROLE DEAL_INTEL_ADMIN COPY CURRENT GRANTS;

-- Warehouse grants (can't transfer ownership of shared warehouses — grant full access)
GRANT ALL PRIVILEGES ON WAREHOUSE IDENTIFIER($pipeline_wh) TO ROLE DEAL_INTEL_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE IDENTIFIER($query_wh)    TO ROLE DEAL_INTEL_ADMIN;

-- Compute pool ownership
GRANT OWNERSHIP ON COMPUTE POOL IDENTIFIER($compute_pool) TO ROLE DEAL_INTEL_ADMIN COPY CURRENT GRANTS;

-- Integration usage
GRANT USAGE ON INTEGRATION DEAL_INTEL_EGRESS_EAI TO ROLE DEAL_INTEL_ADMIN;

-- Cortex AI
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- STEP 5: SECURITYADMIN — Assign role to deploy user
-- =============================================================================

USE ROLE SECURITYADMIN;

GRANT ROLE DEAL_INTEL_ADMIN TO USER IDENTIFIER($deploy_user);

-- =============================================================================
-- STEP 6: Verification
-- =============================================================================

SHOW GRANTS TO ROLE DEAL_INTEL_ADMIN;
SHOW GRANTS OF ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- AFTER THIS SCRIPT:
--
-- The DEAL_INTEL_ADMIN role can:
--   - CREATE/ALTER/DROP any object in DEAL_INTEL database (owns it)
--   - snow app deploy (BIND SERVICE ENDPOINT + owns compute pool)
--   - GRANT CALLER PRIVILEGES (MANAGE CALLER GRANTS)
--   - CREATE/EXECUTE tasks (EXECUTE TASK on account)
--   - Use Cortex AI functions (CORTEX_USER)
--   - Manage EAI (CREATE INTEGRATION + USAGE on existing)
--
-- What still requires admin (intentionally excluded):
--   - Create new databases → ask DBA
--   - Account-level network policies → SECURITYADMIN
--   - Add new compute pools → SYSADMIN
-- =============================================================================
