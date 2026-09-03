-- =============================================================================
-- DEAL_INTEL: Sector Management + Entitlement Roles
-- File: sql/11_entitlement_roles.sql
-- Description: Master sector table, entitlement role templates, and role assignment
-- Run as: DEAL_INTEL_ADMIN (DDL) + grants
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;

-- =============================================================================
-- INVESTMENT SECTORS (Master Table)
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.investment_sectors (
    sector_id       NUMBER AUTOINCREMENT PRIMARY KEY,
    sector_code     VARCHAR(20) NOT NULL,
    sector_name     VARCHAR(256) NOT NULL,
    description     VARCHAR(1000),
    is_default      BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    sort_order      NUMBER DEFAULT 0,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE(sector_code),
    UNIQUE(sector_name)
);

COMMENT ON TABLE DEAL_INTEL.ADMIN.investment_sectors IS
  'Master list of investment sectors. Admin-managed. Drives extraction prompts, filters, and entitlements.';

-- Seed sectors
MERGE INTO DEAL_INTEL.ADMIN.investment_sectors AS tgt
USING (
    SELECT column1 AS sector_code, column2 AS sector_name, column3 AS description, column4 AS is_default, column5 AS sort_order
    FROM VALUES
        ('DINFRA', 'Digital Infrastructure',       'Data centers, fiber networks, towers, edge computing', TRUE, 1),
        ('TRANS',  'Transportation & Logistics',   'Ports, rail, airports, fleet logistics, warehousing', FALSE, 2),
        ('ENERGY', 'Energy Transition',            'Renewables, power generation, storage, grid services', FALSE, 3),
        ('WATER',  'Water & Environmental',        'Water utilities, waste management, environmental services', FALSE, 4),
        ('SOCIAL', 'Social Infrastructure',        'Healthcare facilities, education, government services', FALSE, 5),
        ('COMM',   'Communications',               'Wireless infrastructure, broadband, satellite', FALSE, 6),
        ('POWER',  'Conventional Power',           'Natural gas generation, midstream, pipelines', FALSE, 7),
        ('MULTI',  'Multi-Sector Platform',        'Platform companies spanning multiple sectors', FALSE, 8)
) AS src ON tgt.sector_code = src.sector_code
WHEN NOT MATCHED THEN INSERT (sector_code, sector_name, description, is_default, sort_order)
VALUES (src.sector_code, src.sector_name, src.description, src.is_default, src.sort_order);

-- =============================================================================
-- ENTITLEMENT ROLES (Role Templates)
-- =============================================================================

CREATE TABLE IF NOT EXISTS DEAL_INTEL.ADMIN.entitlement_roles (
    role_id         NUMBER AUTOINCREMENT PRIMARY KEY,
    role_name       VARCHAR(256) NOT NULL,
    description     VARCHAR(1000),
    menu_access     ARRAY,
    sector_access      ARRAY,
    doc_type_access ARRAY,
    can_download    BOOLEAN DEFAULT TRUE,
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      VARCHAR(256),
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE(role_name)
);

COMMENT ON TABLE DEAL_INTEL.ADMIN.entitlement_roles IS
  'Named entitlement role templates. Users assigned to a role inherit its access arrays.';

-- Seed default roles
MERGE INTO DEAL_INTEL.ADMIN.entitlement_roles AS tgt
USING (
    SELECT 'Administrator' AS role_name, 'Full access to all features, data, and admin UI' AS description,
           ARRAY_CONSTRUCT('dashboard','documents','search','review','chat','analytics','saved','admin:pipeline','admin:registry','admin:quality','admin:cost','admin:extraction','admin:labels','admin:sectors','admin:notifications','admin:config','admin:audit','admin:users') AS menu_access,
           ARRAY_CONSTRUCT('*') AS sector_access,
           ARRAY_CONSTRUCT('*') AS doc_type_access,
           TRUE AS can_download
    UNION ALL
    SELECT 'Deal Team', 'Full access to deal sourcing, DD, and transaction documents',
           ARRAY_CONSTRUCT('dashboard','search','chat','analytics','documents','saved'),
           ARRAY_CONSTRUCT('DINFRA','TRANS','ENERGY','WATER','SOCIAL','COMM','POWER','MULTI'),
           ARRAY_CONSTRUCT('Investment Memo','Term Sheet','IC Presentation','Teaser / CIM','DD Report','Legal DD','Tax DD','Environmental DD','SPA','Credit Agreement','Side Letter','Closing Checklist','Valuation Memo'),
           TRUE
    UNION ALL
    SELECT 'Investment Committee', 'Access to IC presentations, memos, and valuations',
           ARRAY_CONSTRUCT('dashboard','search','chat','analytics','documents','saved'),
           ARRAY_CONSTRUCT('*'),
           ARRAY_CONSTRUCT('IC Presentation','Investment Memo','Valuation Memo','DD Report','Term Sheet','Board Deck','Quarterly Report'),
           TRUE
    UNION ALL
    SELECT 'Portfolio Operations', 'Access to portfolio management and reporting documents',
           ARRAY_CONSTRUCT('dashboard','search','chat','documents','saved'),
           ARRAY_CONSTRUCT('*'),
           ARRAY_CONSTRUCT('Board Deck','Quarterly Report','Budget / Forecast','Valuation Memo','Add-On Memo','Operational KPI Report'),
           TRUE
    UNION ALL
    SELECT 'Investor Relations', 'Access to LP-facing reports and capital activity notices',
           ARRAY_CONSTRUCT('dashboard','search','documents'),
           ARRAY_CONSTRUCT('*'),
           ARRAY_CONSTRUCT('LP Report','Capital Call Notice','Distribution Notice','K-1','Fund Performance Report','Investor Letter'),
           FALSE
    UNION ALL
    SELECT 'Compliance', 'Access to regulatory and compliance filings',
           ARRAY_CONSTRUCT('dashboard','search','documents'),
           ARRAY_CONSTRUCT('*'),
           ARRAY_CONSTRUCT('Regulatory Filing','HSR Filing','CFIUS Notice','Compliance Certificate','Anti-Corruption Report'),
           FALSE
    UNION ALL
    SELECT 'Viewer', 'Read-only access to dashboard and search only',
           ARRAY_CONSTRUCT('dashboard','search'),
           ARRAY_CONSTRUCT('*'),
           ARRAY_CONSTRUCT('*'),
           FALSE
) AS src ON tgt.role_name = src.role_name
WHEN NOT MATCHED THEN INSERT (role_name, description, menu_access, sector_access, doc_type_access, can_download, created_by)
VALUES (src.role_name, src.description, src.menu_access, src.sector_access, src.doc_type_access, src.can_download, 'SYSTEM');

-- =============================================================================
-- ALTER user_entitlements to support role assignment
-- =============================================================================

-- Add role FK column (nullable — NULL means direct/custom entitlements)
ALTER TABLE DEAL_INTEL.ADMIN.user_entitlements
  ADD COLUMN IF NOT EXISTS entitlement_role_id NUMBER;

-- =============================================================================
-- GRANTS
-- =============================================================================

-- Admin: full CRUD on sectors and roles
GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.investment_sectors TO ROLE DEAL_INTEL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON DEAL_INTEL.ADMIN.entitlement_roles TO ROLE DEAL_INTEL_ADMIN;

-- User: read sectors (for filter dropdowns) and roles (for display)
GRANT SELECT ON DEAL_INTEL.ADMIN.investment_sectors TO ROLE DEAL_INTEL_USER;
GRANT SELECT ON DEAL_INTEL.ADMIN.entitlement_roles TO ROLE DEAL_INTEL_USER;

-- Pipeline: read access
GRANT SELECT ON DEAL_INTEL.ADMIN.investment_sectors TO ROLE DEAL_INTEL_PIPELINE;
GRANT SELECT ON DEAL_INTEL.ADMIN.entitlement_roles TO ROLE DEAL_INTEL_PIPELINE;
