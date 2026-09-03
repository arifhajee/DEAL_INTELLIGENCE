-- =============================================================================
-- DEAL_INTEL: Sample Data for Testing
-- File: sql/07_sample_data.sql
-- Description: Insert representative sample metadata for demo/testing purposes
-- Run as: DEAL_INTEL_ADMIN — NOTE: actual PDF files must be PUT to stage
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA DATA;
USE WAREHOUSE DEAL_INTEL_WH;

-- =============================================================================
-- SAMPLE METADATA: Insert representative deal document metadata
-- These rows simulate what would arrive via stage upload.
-- In production, these are loaded automatically from @deal_documents_stage.
-- =============================================================================

-- Sample 1: Data Center Platform Acquisition — IC Presentation
INSERT INTO DEAL_INTEL.DATA.ingestion_registry (
    file_path, stage_name, file_format, file_size_bytes,
    ir_file_id, source_folder, ir_document_type,
    ir_policy_number, ir_claim_number, ir_assigned_to, ir_date_created,
    ir_metadata, ingestion_status, processing_version
) SELECT
    'deals/DINFRA-2024-001-ic-presentation.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 1845760,
    'DEAL-00001', 'Deal Sourcing', 'IC Presentation',
    NULL, NULL, 'michael.chen@dealintelligence.com',
    '2024-03-15 09:00:00',
    PARSE_JSON('{"FileID":"DEAL-00001","FileName":"Project Hyperscale IC Presentation","Folder":"Deal Sourcing","DocumentType":"IC Presentation","DealCode":"DINFRA-2024-001","AssignedTo":"michael.chen@dealintelligence.com","DateCreated":"2024-03-15T09:00:00","PageCount":45}'),
    'COMPLETE', 1;

INSERT INTO DEAL_INTEL.DATA.parsed_documents (
    file_path, stage_name, file_format, processing_version,
    parse_mode, page_count, raw_content, parse_status, parse_completed_at
) SELECT
    'deals/DINFRA-2024-001-ic-presentation.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 1, 'LAYOUT', 45,
    'INVESTMENT COMMITTEE PRESENTATION\n\nProject Hyperscale — Data Center Platform Acquisition\nDealIntelligence Infrastructure Fund V\nMarch 2024\n\nEXECUTIVE SUMMARY\n\nDealIntelligence proposes to acquire a 100% interest in Hyperscale Data Centers, LLC (\"Hyperscale\" or the \"Company\"), a leading owner-operator of hyperscale and enterprise colocation data centers across North America.\n\nTarget Company: Hyperscale Data Centers, LLC\nSector: Digital Infrastructure\nGeography: United States (primary), Canada\nDeal Stage: IC Review\nFund: DealIntelligence Infrastructure Fund V\n\nTRANSACTION SUMMARY\nEnterprise Value: $2.8 billion\nEquity Check: $1.4 billion\nNet Debt: $1.4 billion (LTV ~50%)\nSource of Funds: Fund V equity + co-invest\nCo-Investors: GIC, ADIA (co-invest allocation)\n\nINVESTMENT THESIS\n1. Secular demand tailwind from AI/ML workloads driving hyperscale capacity expansion\n2. Contracted revenue base with investment-grade counterparties (AWS, Azure, Google)\n3. Significant organic growth pipeline — 200MW of entitled land bank\n4. Platform for consolidation of smaller operators\n\nRETURN PROFILE\nTarget Gross IRR: 18-22%\nTarget Gross MOIC: 2.2-2.5x\nExpected Hold Period: 4-5 years\nExit Path: Strategic sale or IPO\n\nKEY RISKS\n1. Power availability and grid interconnection delays\n2. Construction cost inflation on development pipeline\n3. Customer concentration (top 3 = 65% of revenue)\n4. Interest rate environment impact on exit multiple\n\nACTION REQUIRED: IC approval to submit binding bid by March 22, 2024.',
    'COMPLETE', '2024-03-15 09:10:00';

INSERT INTO DEAL_INTEL.DATA.classified_documents (
    file_path, processing_version, primary_document_type, all_document_types,
    confidence_score, ir_document_type, classification_match, needs_review
) SELECT
    'deals/DINFRA-2024-001-ic-presentation.pdf', 1,
    'IC Presentation', ARRAY_CONSTRUCT('IC Presentation', 'Investment Memo'),
    0.96, 'IC Presentation', TRUE, FALSE;

INSERT INTO DEAL_INTEL.DATA.document_attributes (
    file_path, processing_version, extracted_attributes,
    document_date, target_company, deal_name, sponsor_name,
    co_investors, sector, deal_stage, fund_name, geography,
    enterprise_value, equity_check, net_debt,
    target_irr, target_moic, investment_date, exit_date,
    holding_period_years, key_risks, action_required,
    doc_status, doc_summary
) SELECT
    'deals/DINFRA-2024-001-ic-presentation.pdf', 1,
    PARSE_JSON('{"response":{"target_company":"Hyperscale Data Centers, LLC","deal_name":"Project Hyperscale","sponsor_name":"DealIntelligence","co_investors":"GIC, ADIA","sector":"Digital Infrastructure","deal_stage":"IC Review","fund_name":"DealIntelligence Infrastructure Fund V","geography":"United States","enterprise_value":"$2.8 billion","equity_check":"$1.4 billion","net_debt":"$1.4 billion","target_irr":"18-22%","target_moic":"2.2-2.5x","investment_date":"2024-04-01","holding_period_years":"4.5","key_risks":"Power availability, construction cost inflation, customer concentration, interest rate impact on exit","action_required":"IC approval to submit binding bid by March 22, 2024","doc_status":"pending IC","doc_summary":"IC presentation for 100% acquisition of Hyperscale Data Centers, a North American hyperscale/colo platform. $2.8B TEV with $1.4B equity from Fund V plus co-invest."}}'),
    '2024-03-15', 'Hyperscale Data Centers, LLC', 'Project Hyperscale', 'DealIntelligence',
    'GIC, ADIA', 'Digital Infrastructure', 'IC Review', 'DealIntelligence Infrastructure Fund V', 'United States',
    '$2.8 billion', '$1.4 billion', '$1.4 billion',
    '18-22%', '2.2-2.5x', '2024-04-01', NULL,
    4.5, 'Power availability, construction cost inflation, customer concentration, interest rate impact on exit',
    'IC approval to submit binding bid by March 22, 2024',
    'pending IC', 'IC presentation for 100% acquisition of Hyperscale Data Centers, a North American hyperscale/colo platform. $2.8B TEV with $1.4B equity from Fund V plus co-invest.';

-- Sample 2: Logistics Add-On — Term Sheet
INSERT INTO DEAL_INTEL.DATA.ingestion_registry (
    file_path, stage_name, file_format, file_size_bytes,
    ir_file_id, source_folder, ir_document_type,
    ir_policy_number, ir_claim_number, ir_assigned_to, ir_date_created,
    ir_metadata, ingestion_status, processing_version
) SELECT
    'deals/TRANS-2024-003-term-sheet.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 524288,
    'DEAL-00002', 'Transaction', 'Term Sheet',
    NULL, NULL, 'sarah.williams@dealintelligence.com',
    '2024-02-20 14:30:00',
    PARSE_JSON('{"FileID":"DEAL-00002","FileName":"Project Gateway Term Sheet","Folder":"Transaction","DocumentType":"Term Sheet","DealCode":"TRANS-2024-003","AssignedTo":"sarah.williams@dealintelligence.com","DateCreated":"2024-02-20T14:30:00","PageCount":8}'),
    'COMPLETE', 1;

INSERT INTO DEAL_INTEL.DATA.parsed_documents (
    file_path, stage_name, file_format, processing_version,
    parse_mode, page_count, raw_content, parse_status, parse_completed_at
) SELECT
    'deals/TRANS-2024-003-term-sheet.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 1, 'LAYOUT', 8,
    'NON-BINDING TERM SHEET\n\nProject Gateway — Logistics Platform Add-On Acquisition\nFebruary 20, 2024\n\nThis non-binding term sheet outlines the principal terms for the acquisition of Gateway Logistics Holdings (\"Gateway\" or \"Target\") by TransPeak Logistics, LLC (\"Buyer\"), a portfolio company of DealIntelligence Infrastructure Fund IV.\n\nTarget: Gateway Logistics Holdings\nBuyer: TransPeak Logistics, LLC (DealIntelligence Fund IV portfolio company)\nSector: Transportation & Logistics\nTransaction Type: Add-On Acquisition\n\nPURCHASE PRICE\nEnterprise Value: $425 million\nEquity Contribution: $215 million (additional Fund IV equity)\nSenior Secured Debt: $210 million (existing TransPeak revolver)\nImplied Multiple: 10.5x LTM Adjusted EBITDA\n\nKEY TERMS\n- 100% acquisition of equity interests\n- Customary representations and warranties\n- $15M escrow (24-month survival)\n- Non-compete: 3 years, nationwide\n- Key management rollover: CEO, CFO, COO\n\nSYNERGY ASSUMPTIONS\n- $18M run-rate cost synergies (fleet optimization, procurement, shared services)\n- $12M revenue synergies (cross-selling to combined customer base)\n- Integration timeline: 12-18 months\n\nCONDITIONS PRECEDENT\n- HSR clearance\n- Lender consent (TransPeak credit facility)\n- Key customer consent (top 5 accounts)\n\nTIMELINE\n- Exclusivity: 45 days from execution\n- Expected closing: Q2 2024\n\nDOC STATUS: Draft — pending GP approval',
    'COMPLETE', '2024-02-20 14:45:00';

INSERT INTO DEAL_INTEL.DATA.classified_documents (
    file_path, processing_version, primary_document_type, all_document_types,
    confidence_score, ir_document_type, classification_match, needs_review
) SELECT
    'deals/TRANS-2024-003-term-sheet.pdf', 1,
    'Term Sheet', ARRAY_CONSTRUCT('Term Sheet', 'Add-On Memo'),
    0.93, 'Term Sheet', TRUE, FALSE;

INSERT INTO DEAL_INTEL.DATA.document_attributes (
    file_path, processing_version, extracted_attributes,
    document_date, target_company, deal_name, sponsor_name,
    co_investors, sector, deal_stage, fund_name, geography,
    enterprise_value, equity_check, net_debt,
    target_irr, target_moic, investment_date, exit_date,
    holding_period_years, key_risks, action_required,
    doc_status, doc_summary
) SELECT
    'deals/TRANS-2024-003-term-sheet.pdf', 1,
    PARSE_JSON('{"response":{"target_company":"Gateway Logistics Holdings","deal_name":"Project Gateway","sponsor_name":"DealIntelligence","sector":"Transportation & Logistics","deal_stage":"Closing","fund_name":"DealIntelligence Infrastructure Fund IV","geography":"United States","enterprise_value":"$425 million","equity_check":"$215 million","net_debt":"$210 million","target_irr":"15-18%","target_moic":"1.8-2.0x","investment_date":"2024-06-01","holding_period_years":"3","key_risks":"HSR clearance timeline, lender consent, customer retention post-merger","action_required":"GP approval, then execute exclusivity agreement","doc_status":"draft","doc_summary":"Non-binding term sheet for $425M add-on acquisition of Gateway Logistics by TransPeak (Fund IV portco). 10.5x EBITDA entry with $30M identified synergies."}}'),
    '2024-02-20', 'Gateway Logistics Holdings', 'Project Gateway', 'DealIntelligence',
    NULL, 'Transportation & Logistics', 'Closing', 'DealIntelligence Infrastructure Fund IV', 'United States',
    '$425 million', '$215 million', '$210 million',
    '15-18%', '1.8-2.0x', '2024-06-01', NULL,
    3.0, 'HSR clearance timeline, lender consent, customer retention post-merger',
    'GP approval, then execute exclusivity agreement',
    'draft', 'Non-binding term sheet for $425M add-on acquisition of Gateway Logistics by TransPeak (Fund IV portco). 10.5x EBITDA entry with $30M identified synergies.';

-- Sample 3: Energy Transition — Due Diligence Report
INSERT INTO DEAL_INTEL.DATA.ingestion_registry (
    file_path, stage_name, file_format, file_size_bytes,
    ir_file_id, source_folder, ir_document_type,
    ir_policy_number, ir_claim_number, ir_assigned_to, ir_date_created,
    ir_metadata, ingestion_status, processing_version
) SELECT
    'deals/ENERGY-2024-002-dd-report.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 3145728,
    'DEAL-00003', 'Due Diligence', 'DD Report',
    NULL, NULL, 'james.park@dealintelligence.com',
    '2024-04-10 11:00:00',
    PARSE_JSON('{"FileID":"DEAL-00003","FileName":"Project Solaris Technical DD Report","Folder":"Due Diligence","DocumentType":"DD Report","DealCode":"ENERGY-2024-002","AssignedTo":"james.park@dealintelligence.com","DateCreated":"2024-04-10T11:00:00","PageCount":78}'),
    'COMPLETE', 1;

INSERT INTO DEAL_INTEL.DATA.parsed_documents (
    file_path, stage_name, file_format, processing_version,
    parse_mode, page_count, raw_content, parse_status, parse_completed_at
) SELECT
    'deals/ENERGY-2024-002-dd-report.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 1, 'LAYOUT', 78,
    'TECHNICAL DUE DILIGENCE REPORT\n\nProject Solaris — Utility-Scale Solar + Storage Platform\nPrepared for: DealIntelligence Partners\nPrepared by: Black & Veatch Advisory\nApril 2024\n\nEXECUTIVE SUMMARY\n\nBlack & Veatch was engaged by DealIntelligence Partners to conduct independent technical due diligence on Solaris Energy Partners, LLC (\"Solaris\"), a utility-scale solar and battery storage platform with 2.1 GW of operating capacity and a 4.5 GW development pipeline across ERCOT, PJM, and CAISO markets.\n\nTarget: Solaris Energy Partners, LLC\nSector: Energy Transition\nCapacity: 2.1 GW operating, 4.5 GW development pipeline\nGeographies: Texas (ERCOT), Mid-Atlantic (PJM), California (CAISO)\n\nKEY FINDINGS\n\n1. OPERATING ASSETS (2.1 GW)\n- Fleet performance: P50 generation within 2% of projections across 12 operating sites\n- Equipment: First Solar Series 6+ modules (2019-2022 vintage), high reliability\n- Availability: 99.1% average (industry benchmark: 98.5%)\n- O&M contracts: Long-term with Recurrent Energy, competitive pricing\n- No material environmental liabilities identified\n\n2. DEVELOPMENT PIPELINE (4.5 GW)\n- 1.8 GW with executed interconnection agreements (completion 2025-2027)\n- 2.7 GW in earlier stages (site control + studies, higher execution risk)\n- Permitting: All 1.8 GW advanced projects have state/county approvals\n- Land: 95% of advanced pipeline on owned/optioned land (low lease risk)\n\n3. REVENUE CONTRACTS\n- 85% of operating capacity under long-term PPA (avg 12 yrs remaining)\n- Counterparties: Investment-grade utilities and C&I offtakers\n- Merchant exposure: 15% (concentrated in ERCOT)\n\n4. STORAGE (480 MWh operating, 1.2 GWh pipeline)\n- 4-hour BESS co-located with solar\n- Revenue stacking: capacity + energy arbitrage + ancillary services\n- Degradation tracking in line with warranty curves\n\nRISK FACTORS\n- Interconnection queue delays for development pipeline (12-18 month risk)\n- IRA transferability market still maturing — potential pricing discount on tax credits\n- Lithium-ion battery supply chain constraints (2025 deliveries)\n\nCONCLUSION\nThe operating portfolio is well-maintained with strong generation performance. The development pipeline represents significant upside but carries typical execution risk. We recommend proceeding with the investment subject to negotiation of appropriate representations regarding interconnection milestones and equipment warranties.',
    'COMPLETE', '2024-04-10 12:30:00';

INSERT INTO DEAL_INTEL.DATA.classified_documents (
    file_path, processing_version, primary_document_type, all_document_types,
    confidence_score, ir_document_type, classification_match, needs_review
) SELECT
    'deals/ENERGY-2024-002-dd-report.pdf', 1,
    'DD Report', ARRAY_CONSTRUCT('DD Report', 'Technical / Engineering DD'),
    0.97, 'DD Report', TRUE, FALSE;

INSERT INTO DEAL_INTEL.DATA.document_attributes (
    file_path, processing_version, extracted_attributes,
    document_date, target_company, deal_name, sponsor_name,
    co_investors, sector, deal_stage, fund_name, geography,
    enterprise_value, equity_check, net_debt,
    target_irr, target_moic, investment_date, exit_date,
    holding_period_years, key_risks, action_required,
    doc_status, doc_summary
) SELECT
    'deals/ENERGY-2024-002-dd-report.pdf', 1,
    PARSE_JSON('{"response":{"target_company":"Solaris Energy Partners, LLC","deal_name":"Project Solaris","sponsor_name":"DealIntelligence","sector":"Energy Transition","deal_stage":"Due Diligence","fund_name":"DealIntelligence Infrastructure Fund V","geography":"United States","enterprise_value":"$1.9 billion","equity_check":"$950 million","net_debt":"$950 million","target_irr":"14-17%","target_moic":"1.9-2.2x","holding_period_years":"5","key_risks":"Interconnection queue delays, IRA tax credit transferability pricing, lithium-ion supply chain","action_required":"Proceed subject to reps on interconnection milestones and equipment warranties","doc_status":"final","doc_summary":"Independent technical DD report on Solaris Energy Partners (2.1GW solar + 480MWh storage operating, 4.5GW pipeline). Positive findings on operating performance, with typical execution risk on development assets."}}'),
    '2024-04-10', 'Solaris Energy Partners, LLC', 'Project Solaris', 'DealIntelligence',
    NULL, 'Energy Transition', 'Due Diligence', 'DealIntelligence Infrastructure Fund V', 'United States',
    '$1.9 billion', '$950 million', '$950 million',
    '14-17%', '1.9-2.2x', NULL, NULL,
    5.0, 'Interconnection queue delays, IRA tax credit transferability pricing, lithium-ion supply chain',
    'Proceed subject to reps on interconnection milestones and equipment warranties',
    'final', 'Independent technical DD report on Solaris Energy Partners (2.1GW solar + 480MWh storage operating, 4.5GW pipeline). Positive findings on operating performance, with typical execution risk on development assets.';

-- Sample 4: Quarterly LP Report
INSERT INTO DEAL_INTEL.DATA.ingestion_registry (
    file_path, stage_name, file_format, file_size_bytes,
    ir_file_id, source_folder, ir_document_type,
    ir_policy_number, ir_claim_number, ir_assigned_to, ir_date_created,
    ir_metadata, ingestion_status, processing_version
) SELECT
    'deals/IR-2024-Q1-lp-report.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 2097152,
    'DEAL-00004', 'Investor Relations', 'LP Report',
    NULL, NULL, 'lisa.martinez@dealintelligence.com',
    '2024-05-01 08:00:00',
    PARSE_JSON('{"FileID":"DEAL-00004","FileName":"DealIntelligence Fund IV Q1 2024 LP Report","Folder":"Investor Relations","DocumentType":"LP Report","FundName":"DealIntelligence Infrastructure Fund IV","AssignedTo":"lisa.martinez@dealintelligence.com","DateCreated":"2024-05-01T08:00:00","PageCount":32}'),
    'COMPLETE', 1;

INSERT INTO DEAL_INTEL.DATA.parsed_documents (
    file_path, stage_name, file_format, processing_version,
    parse_mode, page_count, raw_content, parse_status, parse_completed_at
) SELECT
    'deals/IR-2024-Q1-lp-report.pdf',
    'DEAL_INTEL.DATA.deal_documents_stage', 'PDF', 1, 'LAYOUT', 32,
    'DEALINTELLIGENCE INFRASTRUCTURE FUND IV, L.P.\nQUARTERLY REPORT — Q1 2024\n\nConfidential — For Limited Partners Only\n\nFUND OVERVIEW\nFund: DealIntelligence Infrastructure Fund IV\nVintage: 2020\nFund Size: $14.0 billion\nInvested Capital: $11.2 billion (80% deployed)\nTotal Value (TVPI): 1.45x\nNet IRR (since inception): 16.2%\nDPI: 0.3x\n\nPORTFOLIO SUMMARY (as of March 31, 2024)\n\n| Company | Sector | Investment Date | Equity | Gross MOIC | Status |\n|---------|--------|-----------------|--------|------------|--------|\n| TransPeak Logistics | Transportation | Jun 2021 | $1.8B | 1.6x | Active |\n| Meridian Fiber | Digital Infra | Sep 2021 | $1.2B | 1.8x | Active |\n| ClearWater Systems | Water | Mar 2022 | $850M | 1.4x | Active |\n| SunBridge Energy | Energy | Dec 2022 | $1.1B | 1.3x | Active |\n| NorthStar Towers | Communications | Jun 2023 | $2.0B | 1.2x | Active |\n| Pacific Ports | Transportation | Nov 2023 | $1.5B | 1.1x | Active |\n\nQ1 2024 HIGHLIGHTS\n- TransPeak completed Gateway Logistics add-on ($425M EV)\n- Meridian Fiber secured $300M enterprise contract with major hyperscaler\n- ClearWater awarded new municipal water treatment concession (15-year term)\n- NorthStar activated 2,500 new tower sites, exceeding quarterly target by 15%\n\nCAPITAL ACTIVITY\n- Distributions: $180M (Pacific Ports refinancing proceeds)\n- Capital Calls: $215M (Gateway add-on equity)\n- Remaining Unfunded: $2.8B\n\nNEXT STEPS\n- Annual meeting scheduled for September 15-16, 2024 in New York\n- Fund IV extension vote materials to be distributed in Q3',
    'COMPLETE', '2024-05-01 08:15:00';

INSERT INTO DEAL_INTEL.DATA.classified_documents (
    file_path, processing_version, primary_document_type, all_document_types,
    confidence_score, ir_document_type, classification_match, needs_review
) SELECT
    'deals/IR-2024-Q1-lp-report.pdf', 1,
    'LP Report', ARRAY_CONSTRUCT('LP Report', 'Fund Performance Report'),
    0.98, 'LP Report', TRUE, FALSE;

INSERT INTO DEAL_INTEL.DATA.document_attributes (
    file_path, processing_version, extracted_attributes,
    document_date, target_company, deal_name, sponsor_name,
    co_investors, sector, deal_stage, fund_name, geography,
    enterprise_value, equity_check, net_debt,
    target_irr, target_moic, investment_date, exit_date,
    holding_period_years, key_risks, action_required,
    doc_status, doc_summary
) SELECT
    'deals/IR-2024-Q1-lp-report.pdf', 1,
    PARSE_JSON('{"response":{"fund_name":"DealIntelligence Infrastructure Fund IV","sponsor_name":"DealIntelligence","sector":"Multi-Sector Platform","deal_stage":"Portfolio","geography":"United States","target_irr":"16.2% net","target_moic":"1.45x TVPI","doc_status":"final","doc_summary":"Q1 2024 quarterly LP report for DealIntelligence Infrastructure Fund IV ($14B, 2020 vintage). Fund is 80% deployed at 1.45x TVPI / 16.2% net IRR across 6 portfolio companies spanning digital infra, transport, water, energy, and communications."}}'),
    '2024-05-01', NULL, NULL, 'DealIntelligence',
    NULL, 'Multi-Sector Platform', 'Portfolio', 'DealIntelligence Infrastructure Fund IV', 'United States',
    NULL, '$11.2 billion', NULL,
    '16.2%', '1.45x', NULL, NULL,
    NULL, NULL,
    'Annual meeting September 15-16, 2024; Fund IV extension vote in Q3',
    'final', 'Q1 2024 quarterly LP report for DealIntelligence Infrastructure Fund IV ($14B, 2020 vintage). Fund is 80% deployed at 1.45x TVPI / 16.2% net IRR across 6 portfolio companies spanning digital infra, transport, water, energy, and communications.';
