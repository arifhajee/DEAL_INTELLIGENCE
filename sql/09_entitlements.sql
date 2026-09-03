-- =============================================================================
-- DEAL_INTEL: Entitlements & App-Level RBAC
-- File: sql/09_entitlements.sql
-- Description: User entitlements table for menu visibility, sector access, and
--              document type access. Managed through the admin UI.
-- Run as: SYSADMIN (table creation) + SECURITYADMIN (grants)
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;

-- =============================================================================
-- ENTITLEMENTS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.user_entitlements (
    id                NUMBER AUTOINCREMENT PRIMARY KEY,
    user_name         VARCHAR(256) NOT NULL,
    app_role          VARCHAR(20) DEFAULT 'user',  -- DEPRECATED: appRole now derived from assigned roles
    menu_access       ARRAY,                       -- DEPRECATED: now comes from entitlement_roles
    sector_access        ARRAY,                       -- DEPRECATED: now comes from entitlement_roles
    doc_type_access   ARRAY,                       -- DEPRECATED: now comes from entitlement_roles
    is_active         BOOLEAN DEFAULT TRUE,
    created_by        VARCHAR(256),
    created_at        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE(user_name)
);

COMMENT ON TABLE DEAL_INTEL.ADMIN.user_entitlements IS
  'User registry for app access. Access control now driven by entitlement_roles via user_role_assignments.';

-- =============================================================================
-- SEED DATA
-- =============================================================================

-- Register known users (access is controlled by role assignments, not these rows)
MERGE INTO DEAL_INTEL.ADMIN.user_entitlements AS tgt
USING (SELECT 'TBOON' AS user_name) AS src ON tgt.user_name = src.user_name
WHEN NOT MATCHED THEN INSERT (user_name, is_active, created_by)
VALUES ('TBOON', TRUE, 'SYSTEM');

MERGE INTO DEAL_INTEL.ADMIN.user_entitlements AS tgt
USING (SELECT 'DEPLOY_USER' AS user_name) AS src ON tgt.user_name = src.user_name
WHEN NOT MATCHED THEN INSERT (user_name, is_active, created_by)
VALUES ('DEPLOY_USER', TRUE, 'SYSTEM');

-- =============================================================================
-- GRANTS
-- =============================================================================

-- Admin role: full CRUD on entitlements
GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.user_entitlements TO ROLE DEAL_INTEL_ADMIN;

-- User role: read own entitlements (enforced by app query filtering on CURRENT_USER())
GRANT SELECT ON DEAL_INTEL.ADMIN.user_entitlements TO ROLE DEAL_INTEL_USER;

-- Pipeline role: read access for any pipeline-level entitlement checks
GRANT SELECT ON DEAL_INTEL.ADMIN.user_entitlements TO ROLE DEAL_INTEL_PIPELINE;
