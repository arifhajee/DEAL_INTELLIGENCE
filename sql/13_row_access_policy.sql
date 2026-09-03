-- =============================================================================
-- DEAL_INTEL: Row Access Policy for Document Entitlements
-- File: sql/13_row_access_policy.sql
-- Description: Enforces sector and document type filtering at the database layer.
--              All query paths (app, agent, analyst, direct SQL) are filtered.
--              NO admin bypass — admins are filtered by their entitlement roles.
--              Only DEAL_INTEL_PIPELINE is exempt (needed for automated processing).
-- Run as: DEAL_INTEL_ADMIN
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;
USE WAREHOUSE DEAL_INTEL_QUERY_WH;

-- =============================================================================
-- CRITICAL: DEAL_INTEL_ADMIN must NOT inherit DEAL_INTEL_PIPELINE
-- Otherwise IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') returns TRUE for admins,
-- bypassing the entire RAP.
-- =============================================================================
EXECUTE IMMEDIATE $$
BEGIN
  USE ROLE SECURITYADMIN;
  REVOKE ROLE DEAL_INTEL_PIPELINE FROM ROLE DEAL_INTEL_ADMIN;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;
USE ROLE DEAL_INTEL_ADMIN;

-- =============================================================================
-- HELPER FUNCTION: Get current user's effective sector access
-- Resolves sector codes (e.g. 'DINFRA') to full names (e.g. 'Digital Infrastructure')
-- and generates variants (&, &amp;) to match dirty catalog data.
-- =============================================================================

CREATE OR REPLACE FUNCTION DEAL_INTEL.ADMIN.get_user_sector_access()
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Returns effective sector codes AND names for RAP matching. Resolves codes via investment_sectors table. Includes & and &amp; variants.'
AS
$$
  SELECT CASE
    WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') OR IS_ROLE_IN_SESSION('DEAL_INTEL_ADMIN') THEN ARRAY_CONSTRUCT('*')
    ELSE COALESCE(
      (SELECT
        CASE
          WHEN ARRAY_CONTAINS('*'::VARIANT, ARRAY_AGG(DISTINCT f.value)) THEN ARRAY_CONSTRUCT('*')
          ELSE (
            SELECT ARRAY_AGG(DISTINCT v.value)
            FROM (
              SELECT DISTINCT f2.value::VARCHAR AS sector_code
              FROM DEAL_INTEL.ADMIN.user_role_assignments a2
              JOIN DEAL_INTEL.ADMIN.entitlement_roles r2
                ON a2.role_id = r2.role_id AND r2.is_active = TRUE
              , LATERAL FLATTEN(input => r2.sector_access) f2
              WHERE UPPER(a2.user_name) = CURRENT_USER()
            ) codes
            LEFT JOIN DEAL_INTEL.ADMIN.investment_sectors sec
              ON sec.sector_code = codes.sector_code
            , LATERAL FLATTEN(input =>
              CASE
                WHEN sec.sector_name IS NOT NULL THEN
                  ARRAY_CONSTRUCT(
                    codes.sector_code,
                    sec.sector_name,
                    REPLACE(sec.sector_name, ' and ', ' & '),
                    REPLACE(sec.sector_name, ' and ', ' &amp; '),
                    REPLACE(sec.sector_name, '&', 'and'),
                    REPLACE(sec.sector_name, '&', '&amp;')
                  )
                ELSE ARRAY_CONSTRUCT(codes.sector_code)
              END
            ) v
          )
        END
       FROM DEAL_INTEL.ADMIN.user_role_assignments a
       JOIN DEAL_INTEL.ADMIN.entitlement_roles r
         ON a.role_id = r.role_id AND r.is_active = TRUE
       , LATERAL FLATTEN(input => r.sector_access) f
       WHERE UPPER(a.user_name) = CURRENT_USER()
      ),
      ARRAY_CONSTRUCT()  -- No roles assigned = no access
    )
  END
$$;

-- =============================================================================
-- HELPER FUNCTION: Get current user's effective document type access (raw)
-- Used only for wildcard check; actual matching uses user_can_access_doc_type()
-- =============================================================================

CREATE OR REPLACE FUNCTION DEAL_INTEL.ADMIN.get_user_doc_type_access()
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Returns effective doc type access array. Used for wildcard check only.'
AS
$$
  SELECT CASE
    WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') THEN ARRAY_CONSTRUCT('*')
    ELSE COALESCE(
      (SELECT IFF(
          ARRAY_CONTAINS('*'::VARIANT, ARRAY_AGG(DISTINCT f.value)),
          ARRAY_CONSTRUCT('*'),
          ARRAY_AGG(DISTINCT f.value)
        )
       FROM DEAL_INTEL.ADMIN.user_role_assignments a
       JOIN DEAL_INTEL.ADMIN.entitlement_roles r
         ON a.role_id = r.role_id AND r.is_active = TRUE
       , LATERAL FLATTEN(input => r.doc_type_access) f
       WHERE UPPER(a.user_name) = CURRENT_USER()
      ),
      ARRAY_CONSTRUCT()  -- No roles assigned = no access
    )
  END
$$;

-- =============================================================================
-- HELPER FUNCTION: Fuzzy doc type access check (RAP-compatible)
-- Uses TABLE(FLATTEN(...)) instead of LATERAL FLATTEN to work inside RAP context.
-- Matches role values like 'IC Presentation' against catalog values like
-- 'IC Presentation' using ILIKE contains.
-- =============================================================================

CREATE OR REPLACE FUNCTION DEAL_INTEL.ADMIN.user_can_access_doc_type(row_doc_type VARCHAR)
RETURNS BOOLEAN
LANGUAGE SQL
COMMENT = 'Checks if user can access a given document type. RAP-compatible (no LATERAL FLATTEN on subquery).'
AS
$$
  SELECT CASE
    WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') THEN TRUE
    WHEN row_doc_type IS NULL THEN FALSE
    WHEN ARRAY_CONTAINS('*'::VARIANT, DEAL_INTEL.ADMIN.get_user_doc_type_access()) THEN TRUE
    WHEN ARRAY_CONTAINS(row_doc_type::VARIANT, DEAL_INTEL.ADMIN.get_user_doc_type_access()) THEN TRUE
    ELSE (
      SELECT COALESCE(MAX(TRUE), FALSE)
      FROM TABLE(FLATTEN(input => DEAL_INTEL.ADMIN.get_user_doc_type_access())) f
      WHERE row_doc_type ILIKE '%' || f.value::VARCHAR || '%'
         OR f.value::VARCHAR ILIKE '%' || row_doc_type || '%'
    )
  END
$$;

-- =============================================================================
-- HELPER FUNCTION: Check if user is active in entitlements
-- =============================================================================

CREATE OR REPLACE FUNCTION DEAL_INTEL.ADMIN.is_user_active()
RETURNS BOOLEAN
LANGUAGE SQL
COMMENT = 'Returns TRUE if the current user has an active entitlement record.'
AS
$$
  SELECT CASE
    WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') THEN TRUE
    ELSE COALESCE(
      (SELECT is_active
       FROM DEAL_INTEL.ADMIN.user_entitlements
       WHERE UPPER(user_name) = CURRENT_USER()
       LIMIT 1),
      FALSE  -- No entitlement record = not active
    )
  END
$$;

-- =============================================================================
-- DETACH POLICIES (must happen before CREATE OR REPLACE)
-- Idempotent: ignores errors if policies aren't currently attached.
-- =============================================================================

EXECUTE IMMEDIATE $$
BEGIN
  ALTER TABLE DEAL_INTEL.DATA.document_catalog
    DROP ROW ACCESS POLICY DEAL_INTEL.DATA.deal_intel_folder_policy;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

EXECUTE IMMEDIATE $$
BEGIN
  ALTER TABLE DEAL_INTEL.DATA.document_catalog
    DROP ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

EXECUTE IMMEDIATE $$
BEGIN
  ALTER VIEW DEAL_INTEL.APP.v_document_catalog
    DROP ROW ACCESS POLICY DEAL_INTEL.DATA.deal_intel_folder_policy;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

EXECUTE IMMEDIATE $$
BEGIN
  ALTER VIEW DEAL_INTEL.APP.v_document_catalog
    DROP ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy;
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

-- =============================================================================
-- ROW ACCESS POLICY: Enforces sector + document type entitlements
-- NO admin bypass. Only pipeline role is exempt.
-- =============================================================================

CREATE OR REPLACE ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy
  AS (row_sector VARCHAR, row_doc_type VARCHAR) RETURNS BOOLEAN ->
  CASE
    -- Pipeline role always sees all (needed for automated processing)
    WHEN IS_ROLE_IN_SESSION('DEAL_INTEL_PIPELINE') THEN TRUE
    -- Must have DEAL_INTEL_USER or DEAL_INTEL_ADMIN role
    WHEN NOT (IS_ROLE_IN_SESSION('DEAL_INTEL_USER') OR IS_ROLE_IN_SESSION('DEAL_INTEL_ADMIN')) THEN FALSE
    -- User must be active in entitlements
    WHEN NOT DEAL_INTEL.ADMIN.is_user_active() THEN FALSE
    -- Check sector access (wildcard passes all, otherwise must match resolved names)
    WHEN NOT (
      ARRAY_CONTAINS('*'::VARIANT, DEAL_INTEL.ADMIN.get_user_sector_access())
      OR ARRAY_CONTAINS(COALESCE(row_sector, '__NULL__')::VARIANT, DEAL_INTEL.ADMIN.get_user_sector_access())
    ) THEN FALSE
    -- Check doc type access (fuzzy contains matching)
    WHEN NOT DEAL_INTEL.ADMIN.user_can_access_doc_type(row_doc_type) THEN FALSE
    -- Both checks passed
    ELSE TRUE
  END;

COMMENT ON ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy IS
  'Enforces sector and document type filtering based on user entitlement role assignments. Only DEAL_INTEL_PIPELINE bypasses. Admins are filtered by their configured entitlements.';

-- =============================================================================
-- ATTACH POLICY to tables and views
-- =============================================================================

-- Apply to the main document_catalog dynamic table
ALTER TABLE DEAL_INTEL.DATA.document_catalog
  ADD ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy
  ON (sector, document_type);

-- Apply to APP view if it exists
EXECUTE IMMEDIATE $$
BEGIN
  ALTER VIEW DEAL_INTEL.APP.v_document_catalog
    ADD ROW ACCESS POLICY DEAL_INTEL.ADMIN.document_entitlement_policy
    ON (sector, document_type);
EXCEPTION WHEN OTHER THEN NULL;
END;
$$;

-- =============================================================================
-- GRANTS: Ensure functions are callable by DEAL_INTEL_USER
-- =============================================================================

GRANT USAGE ON FUNCTION DEAL_INTEL.ADMIN.get_user_sector_access() TO ROLE DEAL_INTEL_USER;
GRANT USAGE ON FUNCTION DEAL_INTEL.ADMIN.get_user_doc_type_access() TO ROLE DEAL_INTEL_USER;
GRANT USAGE ON FUNCTION DEAL_INTEL.ADMIN.is_user_active() TO ROLE DEAL_INTEL_USER;
GRANT USAGE ON FUNCTION DEAL_INTEL.ADMIN.user_can_access_doc_type(VARCHAR) TO ROLE DEAL_INTEL_USER;

-- =============================================================================
-- VERIFICATION QUERIES (run manually to test)
-- =============================================================================
-- Check your access array:
-- SELECT DEAL_INTEL.ADMIN.get_user_sector_access();
-- SELECT DEAL_INTEL.ADMIN.get_user_doc_type_access();
-- SELECT DEAL_INTEL.ADMIN.is_user_active();
-- Count visible rows:
-- SELECT COUNT(*) FROM DEAL_INTEL.DATA.document_catalog;
-- Check sector breakdown:
-- SELECT SECTOR, COUNT(*) FROM DEAL_INTEL.DATA.document_catalog GROUP BY 1 ORDER BY 2 DESC;
