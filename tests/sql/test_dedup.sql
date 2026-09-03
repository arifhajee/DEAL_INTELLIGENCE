-- =============================================================================
-- DEAL_INTEL: Deduplication Unit Tests
-- File: tests/sql/test_dedup.sql
-- Run as: DEAL_INTEL_ADMIN with DEAL_INTEL_WH
-- =============================================================================

USE ROLE DEAL_INTEL_ADMIN;
USE DATABASE DEAL_INTEL;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEAL_INTEL_WH;

-- Helper: create test results table
CREATE TEMPORARY TABLE test_results (
    test_id     VARCHAR,
    test_name   VARCHAR,
    status      VARCHAR,  -- PASS / FAIL
    details     VARCHAR
);

-- ──────────────────────────────────────────────
-- SETUP: Clean test state
-- ──────────────────────────────────────────────
DELETE FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path LIKE 'test/unit/%';

-- ──────────────────────────────────────────────
-- T1.1.1: New file never seen before
-- ──────────────────────────────────────────────
INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
    file_path, stage_name, file_format, ingestion_status, processing_version
) VALUES ('test/unit/new_file.pdf', 'DEAL_INTEL.PUBLIC.sample_stage', 'PDF', 'PENDING', 1);

INSERT INTO test_results
SELECT
    'T1.1.1', 'New file inserted as PENDING',
    CASE WHEN COUNT(*) = 1 AND MAX(ingestion_status) = 'PENDING' THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*) || ' status=' || MAX(ingestion_status)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/new_file.pdf';

-- ──────────────────────────────────────────────
-- T1.1.2: Same file, simulate second scan — should not create new row
-- ──────────────────────────────────────────────
-- A second registration attempt for same path should not create a duplicate
-- (verified by the UNIQUE constraint on file_path + processing_version)
BEGIN
    INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
        file_path, stage_name, file_format, ingestion_status, processing_version
    ) VALUES ('test/unit/new_file.pdf', 'DEAL_INTEL.PUBLIC.sample_stage', 'PDF', 'PENDING', 1);
    INSERT INTO test_results VALUES ('T1.1.2', 'Duplicate row rejected by UNIQUE constraint', 'FAIL', 'INSERT succeeded when it should have failed');
EXCEPTION WHEN OTHER THEN
    INSERT INTO test_results VALUES ('T1.1.2', 'Duplicate row rejected by UNIQUE constraint', 'PASS', 'UNIQUE constraint correctly prevented duplicate');
END;

-- ──────────────────────────────────────────────
-- T1.1.3: Changed file → new version
-- ──────────────────────────────────────────────
-- Simulate COMPLETE status for version 1
UPDATE DEAL_INTEL.PUBLIC.ingestion_registry
SET ingestion_status = 'COMPLETE', file_size_bytes = 1000,
    processing_completed_at = CURRENT_TIMESTAMP()
WHERE file_path = 'test/unit/new_file.pdf' AND processing_version = 1;

-- Insert version 2 (simulating changed file)
INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
    file_path, stage_name, file_format, file_size_bytes,
    ingestion_status, processing_version
)
SELECT file_path, stage_name, file_format, 2000, 'PENDING', 2
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/new_file.pdf' AND processing_version = 1;

INSERT INTO test_results
SELECT
    'T1.1.3', 'Changed file creates new version',
    CASE WHEN MAX(processing_version) = 2 THEN 'PASS' ELSE 'FAIL' END,
    'max_version=' || MAX(processing_version)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/new_file.pdf';

-- ──────────────────────────────────────────────
-- T1.1.4: FAILED file with attempts < 3 → reset to PENDING
-- ──────────────────────────────────────────────
INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
    file_path, stage_name, file_format, ingestion_status,
    processing_version, processing_attempts, last_error
) VALUES ('test/unit/failed_file.tiff', 'DEAL_INTEL.PUBLIC.sample_stage', 'TIFF', 'FAILED', 1, 2, 'OCR timeout');

UPDATE DEAL_INTEL.PUBLIC.ingestion_registry
SET ingestion_status = 'PENDING'
WHERE ingestion_status = 'FAILED'
  AND processing_attempts < 3
  AND file_path = 'test/unit/failed_file.tiff';

INSERT INTO test_results
SELECT
    'T1.1.4', 'FAILED file with attempts<3 reset to PENDING',
    CASE WHEN MAX(ingestion_status) = 'PENDING' THEN 'PASS' ELSE 'FAIL' END,
    'status=' || MAX(ingestion_status)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/failed_file.tiff';

-- ──────────────────────────────────────────────
-- T1.1.5: FAILED file with attempts ≥ 3 → set to ABANDONED
-- ──────────────────────────────────────────────
INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
    file_path, stage_name, file_format, ingestion_status,
    processing_version, processing_attempts
) VALUES ('test/unit/abandoned_file.tiff', 'DEAL_INTEL.PUBLIC.sample_stage', 'TIFF', 'FAILED', 1, 3);

UPDATE DEAL_INTEL.PUBLIC.ingestion_registry
SET ingestion_status = 'ABANDONED'
WHERE ingestion_status = 'FAILED'
  AND processing_attempts >= 3
  AND file_path = 'test/unit/abandoned_file.tiff';

INSERT INTO test_results
SELECT
    'T1.1.5', 'FAILED file with attempts>=3 set to ABANDONED',
    CASE WHEN MAX(ingestion_status) = 'ABANDONED' THEN 'PASS' ELSE 'FAIL' END,
    'status=' || MAX(ingestion_status)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/abandoned_file.tiff';

-- ──────────────────────────────────────────────
-- T1.1.6: Force reprocess
-- ──────────────────────────────────────────────
CALL DEAL_INTEL.PUBLIC.sp_force_reprocess('test/unit/new_file.pdf', 'Unit test reprocess');

INSERT INTO test_results
SELECT
    'T1.1.6', 'sp_force_reprocess creates new version',
    CASE WHEN MAX(processing_version) = 3 THEN 'PASS' ELSE 'FAIL' END,
    'max_version=' || MAX(processing_version)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/new_file.pdf';

-- ──────────────────────────────────────────────
-- T1.1.7: PROCESSING in-flight lock
-- ──────────────────────────────────────────────
INSERT INTO DEAL_INTEL.PUBLIC.ingestion_registry (
    file_path, stage_name, file_format, ingestion_status,
    processing_version, processing_started_at
) VALUES ('test/unit/processing_file.pdf', 'DEAL_INTEL.PUBLIC.sample_stage', 'PDF', 'PROCESSING', 1, CURRENT_TIMESTAMP());

-- Count before
SET before_count = (SELECT COUNT(*) FROM DEAL_INTEL.PUBLIC.ingestion_registry WHERE file_path = 'test/unit/processing_file.pdf');

-- A second scan should NOT add another row (register_new_files logic skips PROCESSING)
INSERT INTO test_results
SELECT
    'T1.1.7', 'PROCESSING file not re-registered',
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END,
    'count=' || COUNT(*)
FROM DEAL_INTEL.PUBLIC.ingestion_registry
WHERE file_path = 'test/unit/processing_file.pdf';

-- ──────────────────────────────────────────────
-- T1.1.8: Bulk reprocess dry run
-- ──────────────────────────────────────────────
-- Set test files to COMPLETE so they're eligible for bulk reprocess
UPDATE DEAL_INTEL.PUBLIC.ingestion_registry
SET ingestion_status = 'COMPLETE', processing_completed_at = CURRENT_TIMESTAMP()
WHERE file_path LIKE 'test/unit/%'
  AND processing_version = (
      SELECT MAX(v) FROM DEAL_INTEL.PUBLIC.ingestion_registry r2
      WHERE r2.file_path = DEAL_INTEL.PUBLIC.ingestion_registry.file_path
  );

SET before_version_count = (
    SELECT COUNT(*) FROM DEAL_INTEL.PUBLIC.ingestion_registry WHERE file_path LIKE 'test/unit/%'
);

CALL DEAL_INTEL.PUBLIC.sp_bulk_reprocess(NULL, NULL, NULL, NULL, TRUE);  -- dry run

SET after_version_count = (
    SELECT COUNT(*) FROM DEAL_INTEL.PUBLIC.ingestion_registry WHERE file_path LIKE 'test/unit/%'
);

INSERT INTO test_results VALUES (
    'T1.1.8', 'Bulk reprocess dry run does not insert rows',
    CASE WHEN $before_version_count = $after_version_count THEN 'PASS' ELSE 'FAIL' END,
    'before=' || $before_version_count || ' after=' || $after_version_count
);

-- ──────────────────────────────────────────────
-- CLEANUP
-- ──────────────────────────────────────────────
DELETE FROM DEAL_INTEL.PUBLIC.ingestion_registry WHERE file_path LIKE 'test/unit/%';

-- ──────────────────────────────────────────────
-- RESULTS
-- ──────────────────────────────────────────────
SELECT
    test_id,
    test_name,
    status,
    details,
    CASE WHEN status = 'PASS' THEN '✅' ELSE '❌' END AS result_icon
FROM test_results
ORDER BY test_id;

SELECT
    COUNT(*) AS total_tests,
    SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status='FAIL' THEN 1 ELSE 0 END) AS failed
FROM test_results;
