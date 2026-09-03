-- =============================================================================
-- DEAL_INTEL: Multi-Role Assignments (replaces single entitlement_role_id)
-- File: sql/12_multi_role_assignments.sql
-- Description: Junction table for multi-role user assignments. Users get access
--              exclusively from roles — no custom/direct entitlements.
-- Run as: DEAL_INTEL_ADMIN (DDL) + grants
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;

-- =============================================================================
-- USER_ROLE_ASSIGNMENTS (Junction Table)
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.user_role_assignments (
    id           NUMBER AUTOINCREMENT PRIMARY KEY,
    user_name    VARCHAR(256) NOT NULL,
    role_id      NUMBER NOT NULL,
    assigned_by  VARCHAR(256),
    assigned_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE(user_name, role_id)
);

COMMENT ON TABLE DEAL_INTEL.ADMIN.user_role_assignments IS
  'Junction table: users can be assigned to multiple entitlement roles. Effective access = union of all assigned roles.';

-- =============================================================================
-- MIGRATE existing single-role assignments
-- =============================================================================

INSERT INTO DEAL_INTEL.ADMIN.user_role_assignments (user_name, role_id, assigned_by)
SELECT u.user_name, u.entitlement_role_id, 'MIGRATION'
FROM DEAL_INTEL.ADMIN.user_entitlements u
WHERE u.entitlement_role_id IS NOT NULL
  AND u.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM DEAL_INTEL.ADMIN.user_role_assignments a
    WHERE a.user_name = u.user_name AND a.role_id = u.entitlement_role_id
  );

-- =============================================================================
-- SEED: Assign Administrator role to default users
-- =============================================================================

MERGE INTO DEAL_INTEL.ADMIN.user_role_assignments AS tgt
USING (
    SELECT u.user_name, r.role_id
    FROM (SELECT 'JOHN' AS user_name UNION ALL SELECT 'DEPLOY_USER') u
    CROSS JOIN DEAL_INTEL.ADMIN.entitlement_roles r
    WHERE r.role_name = 'Administrator'
) AS src ON tgt.user_name = src.user_name AND tgt.role_id = src.role_id
WHEN NOT MATCHED THEN INSERT (user_name, role_id, assigned_by)
VALUES (src.user_name, src.role_id, 'SYSTEM');

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.user_role_assignments TO ROLE DEAL_INTEL_ADMIN;
GRANT SELECT ON DEAL_INTEL.ADMIN.user_role_assignments TO ROLE DEAL_INTEL_USER;
GRANT SELECT ON DEAL_INTEL.ADMIN.user_role_assignments TO ROLE DEAL_INTEL_PIPELINE;
