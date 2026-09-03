-- =============================================================================
-- SEED: Classification Labels for Infrastructure PE Document Pipeline
-- =============================================================================
-- Idempotent: uses MERGE pattern
-- Run via: ./deploy.sh --seed-data
-- Categories: Deal Sourcing, Due Diligence, Transaction, Portfolio Management,
--             Investor Relations, Compliance, Financial, General
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA ADMIN;

MERGE INTO classification_labels tgt
USING (
    SELECT column1 AS label, column2 AS category, column3 AS sort_order
    FROM VALUES
        -- ─── Deal Sourcing ───────────────────────────────────────────────────────
        ('Investment Memo',                     'Deal Sourcing',     1),
        ('Teaser / CIM',                        'Deal Sourcing',     2),
        ('IC Presentation',                     'Deal Sourcing',     3),
        ('Term Sheet',                          'Deal Sourcing',     4),
        ('Management Presentation',             'Deal Sourcing',     5),
        ('Information Request List (IRL)',       'Deal Sourcing',     6),

        -- ─── Due Diligence ───────────────────────────────────────────────────────
        ('DD Report',                           'Due Diligence',    10),
        ('Commercial DD',                       'Due Diligence',    11),
        ('Legal DD',                            'Due Diligence',    12),
        ('Tax DD',                              'Due Diligence',    13),
        ('Environmental DD',                    'Due Diligence',    14),
        ('Insurance DD',                        'Due Diligence',    15),
        ('Technical / Engineering DD',          'Due Diligence',    16),
        ('Market Study',                        'Due Diligence',    17),
        ('Quality of Earnings (QoE)',           'Due Diligence',    18),

        -- ─── Transaction Documents ───────────────────────────────────────────────
        ('SPA / Purchase Agreement',            'Transaction',      20),
        ('Credit Agreement',                    'Transaction',      21),
        ('Shareholders Agreement',              'Transaction',      22),
        ('Side Letter',                         'Transaction',      23),
        ('Closing Checklist',                   'Transaction',      24),
        ('Escrow Agreement',                    'Transaction',      25),
        ('Financing Commitment Letter',         'Transaction',      26),
        ('Add-On Memo',                         'Transaction',      27),

        -- ─── Portfolio Management ────────────────────────────────────────────────
        ('Board Deck',                          'Portfolio',        30),
        ('Quarterly Report',                    'Portfolio',        31),
        ('Budget / Forecast',                   'Portfolio',        32),
        ('Valuation Memo',                      'Portfolio',        33),
        ('Operational KPI Report',              'Portfolio',        34),
        ('Asset Management Plan',               'Portfolio',        35),
        ('Exit Readiness Assessment',           'Portfolio',        36),

        -- ─── Investor Relations ──────────────────────────────────────────────────
        ('LP Report',                           'Investor Relations', 40),
        ('Capital Call Notice',                 'Investor Relations', 41),
        ('Distribution Notice',                 'Investor Relations', 42),
        ('K-1 / Tax Document',                  'Investor Relations', 43),
        ('Fund Performance Report',             'Investor Relations', 44),
        ('Investor Letter',                     'Investor Relations', 45),
        ('PPM / Offering Memorandum',           'Investor Relations', 46),

        -- ─── Compliance & Regulatory ─────────────────────────────────────────────
        ('Regulatory Filing',                   'Compliance',       50),
        ('HSR Filing',                          'Compliance',       51),
        ('CFIUS Notice',                        'Compliance',       52),
        ('Anti-Corruption Report',              'Compliance',       53),
        ('ESG / Sustainability Report',         'Compliance',       54),
        ('Compliance Certificate',              'Compliance',       55),

        -- ─── Financial ───────────────────────────────────────────────────────────
        ('Financial Model',                     'Financial',        60),
        ('Audited Financial Statements',        'Financial',        61),
        ('Debt Schedule / Cap Table',           'Financial',        62),
        ('Insurance Policy Schedule',           'Financial',        63),

        -- ─── Correspondence & General ────────────────────────────────────────────
        ('Legal Opinion',                       'Correspondence',   70),
        ('Broker Correspondence',               'Correspondence',   71),
        ('Internal Memo',                       'Correspondence',   72),
        ('NDA / Confidentiality Agreement',     'Correspondence',   73)
) AS src (label, category, sort_order)
ON tgt.label = src.label
WHEN NOT MATCHED THEN
    INSERT (label, category, sort_order, is_active)
    VALUES (src.label, src.category, src.sort_order, TRUE);
