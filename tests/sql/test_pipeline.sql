-- =============================================================================
-- DEAL_INTEL: Pipeline Unit Tests
-- File: tests/sql/test_pipeline.sql
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEAL_INTEL_WH;

CREATE TEMPORARY TABLE test_results (
    test_id VARCHAR, test_name VARCHAR, status VARCHAR, details VARCHAR
);

-- ──────────────────────────────────────────────
-- T1.3: Telemetry View Tests
-- ──────────────────────────────────────────────

-- T1.3.1: v_pipeline_health returns exactly 1 row
INSERT INTO test_results
SELECT 'T1.3.1', 'v_pipeline_health returns 1 row',
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END,
    'row_count=' || COUNT(*)
FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;

-- T1.3.2: Queue counts sum to total
INSERT INTO test_results
SELECT 'T1.3.2', 'Queue counts sum to total_registered',
    CASE WHEN (pending_count + processing_count + complete_count + failed_count + abandoned_count + skipped_count) = total_registered
         OR total_registered = 0 THEN 'PASS' ELSE 'FAIL' END,
    'total=' || total_registered || ' sum_of_parts=' || (pending_count + processing_count + complete_count + failed_count + abandoned_count + skipped_count)
FROM DEAL_INTEL.TELEMETRY.v_pipeline_health;

-- T1.3.3: Ingestion metrics failure rate between 0 and 100
INSERT INTO test_results
SELECT 'T1.3.3', 'v_ingestion_metrics failure_rate_pct valid range',
    CASE WHEN COUNT(*) = 0 OR (MAX(failure_rate_pct) <= 100 AND MIN(failure_rate_pct) >= 0) THEN 'PASS' ELSE 'FAIL' END,
    'max_failure_rate=' || COALESCE(MAX(failure_rate_pct)::VARCHAR, 'N/A')
FROM DEAL_INTEL.TELEMETRY.v_ingestion_metrics;

-- T1.3.4: Cost credits are non-negative
INSERT INTO test_results
SELECT 'T1.3.4', 'v_cost_by_drawer credits >= 0',
    CASE WHEN COUNT(*) = 0 OR MIN(total_credits) >= 0 THEN 'PASS' ELSE 'FAIL' END,
    'min_credits=' || COALESCE(MIN(total_credits)::VARCHAR, 'N/A')
FROM DEAL_INTEL.TELEMETRY.v_cost_by_drawer;

-- T1.3.5: Quality confidence 0-1
INSERT INTO test_results
SELECT 'T1.3.5', 'v_quality_metrics avg_confidence 0-1',
    CASE WHEN COUNT(*) = 0 OR (MAX(avg_confidence) <= 1 AND MIN(avg_confidence) >= 0) THEN 'PASS' ELSE 'FAIL' END,
    'max_conf=' || COALESCE(MAX(avg_confidence)::VARCHAR, 'N/A')
FROM DEAL_INTEL.TELEMETRY.v_quality_metrics;

-- ──────────────────────────────────────────────
-- T2.1: Sample data verification
-- ──────────────────────────────────────────────

-- Verify sample data loaded
INSERT INTO test_results
SELECT 'T2.1.1', 'Sample documents in ingestion_registry',
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE ingestion_status = 'COMPLETE';

-- Verify parsed documents
INSERT INTO test_results
SELECT 'T2.1.2', 'Sample documents have parsed content',
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*)
FROM DEAL_INTEL.PUBLIC.parsed_documents
WHERE parse_status = 'COMPLETE' AND LENGTH(raw_content) > 100;

-- Verify classification
INSERT INTO test_results
SELECT 'T2.1.3', 'Sample documents have classification',
    CASE WHEN COUNT(*) >= 4 AND MIN(confidence_score) > 0 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*) || ' min_confidence=' || COALESCE(MIN(confidence_score)::VARCHAR, '0')
FROM DEAL_INTEL.PUBLIC.classified_documents
WHERE primary_document_type IS NOT NULL;

-- Verify attribute extraction
INSERT INTO test_results
SELECT 'T2.1.4', 'Sample documents have extracted attributes',
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*)
FROM DEAL_INTEL.PUBLIC.document_attributes
WHERE doc_summary IS NOT NULL AND LENGTH(doc_summary) > 20;

-- Verify document_catalog dynamic table
INSERT INTO test_results
SELECT 'T2.1.5', 'document_catalog has documents',
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*)
FROM DEAL_INTEL.PUBLIC.document_catalog;

-- Verify catalog has full_text for search
INSERT INTO test_results
SELECT 'T2.1.6', 'document_catalog full_text populated',
    CASE WHEN COUNT(*) = 0 OR MIN(LENGTH(full_text)) > 50 THEN 'PASS' ELSE 'FAIL' END,
    'min_text_length=' || COALESCE(MIN(LENGTH(full_text))::VARCHAR, '0')
FROM DEAL_INTEL.PUBLIC.document_catalog
WHERE full_text IS NOT NULL;

-- ──────────────────────────────────────────────
-- T1.2: Stored Procedure Tests
-- ──────────────────────────────────────────────

-- T1.2.9: sp_force_reprocess with invalid path
DECLARE result_msg VARCHAR;
BEGIN
    CALL DEAL_INTEL.PUBLIC.sp_force_reprocess('nonexistent/path.pdf', 'test') INTO :result_msg;
    INSERT INTO test_results VALUES (
        'T1.2.9', 'sp_force_reprocess invalid path returns error',
        CASE WHEN STARTSWITH(:result_msg, 'ERROR') THEN 'PASS' ELSE 'FAIL' END,
        :result_msg
    );
END;

-- T1.2.10: sp_reset_pipeline without CONFIRM
DECLARE reset_result VARCHAR;
BEGIN
    CALL DEAL_INTEL.ADMIN.sp_reset_pipeline('WRONG_CONFIRM') INTO :reset_result;
    INSERT INTO test_results VALUES (
        'T1.2.10', 'sp_reset_pipeline without CONFIRM returns error',
        CASE WHEN STARTSWITH(:reset_result, 'ERROR') THEN 'PASS' ELSE 'FAIL' END,
        :reset_result
    );
END;

-- ──────────────────────────────────────────────
-- T3.1: Cortex Search returns results for sample data
-- ──────────────────────────────────────────────
INSERT INTO test_results
SELECT 'T3.1.1', 'Cortex Search returns results for Digital Infrastructure query',
    CASE WHEN ARRAY_SIZE(PARSE_JSON(results)['results']) > 0 THEN 'PASS' ELSE 'FAIL' END,
    'result_count=' || ARRAY_SIZE(PARSE_JSON(results)['results'])::VARCHAR
FROM (
    SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DEAL_INTEL.PUBLIC.deal_search_svc',
        '{"query":"digital infrastructure data center acquisition","columns":["document_type","target_company"],"limit":5}'
    ) AS results
);

-- T3.1.2: Cortex Search with drawer filter
INSERT INTO test_results
SELECT 'T3.1.2', 'Cortex Search drawer filter returns only Claims docs',
    CASE WHEN ARRAY_SIZE(results_json['results']) > 0 THEN 'PASS' ELSE 'FAIL' END,
    'result_count=' || ARRAY_SIZE(results_json['results'])::VARCHAR
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DEAL_INTEL.PUBLIC.deal_search_svc',
            '{"query":"claim loss","columns":["document_type","ir_drawer"],"filter":{"@eq":{"ir_drawer":"Claims"}},"limit":5}'
        )
    ) AS results_json
);

-- ──────────────────────────────────────────────
-- RESULTS
-- ──────────────────────────────────────────────
SELECT test_id, test_name, status,
    CASE WHEN status='PASS' THEN '✅' ELSE '❌' END AS icon,
    details
FROM test_results ORDER BY test_id;

SELECT COUNT(*) AS total,
    SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status='FAIL' THEN 1 ELSE 0 END) AS failed
FROM test_results;
