#!/bin/bash
# =============================================================================
# DEAL_INTEL: Unified Deployment Script
# =============================================================================
# Usage:
#   ./deploy.sh                    Full deploy (infra + app + grants)
#   ./deploy.sh --infra-only       Database infrastructure only (no app deploy)
#   ./deploy.sh --app-only         App deploy + post-deploy grants only
#   ./deploy.sh --skip-sample-data Skip 07_sample_data.sql
#   ./deploy.sh --seed-data         Seed classification labels and extraction schemas
#   ./deploy.sh --dry-run          Show what would be executed without running
#
# Prerequisites:
#   - Snowflake CLI (`snow`) installed and configured
#   - Connection with DEAL_INTEL_ADMIN role (run 00_provision_account.sql first)
#   - 00_provision_account.sql already executed by ACCOUNTADMIN (one-time)
# =============================================================================

set -euo pipefail

# --- Load Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/deploy.config"
SQL_DIR="${SCRIPT_DIR}/sql"
APP_DIR="${SCRIPT_DIR}/app"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: deploy.config not found at $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# --- Flags ---
INFRA_ONLY=false
APP_ONLY=false
SKIP_SAMPLE=false
SEED_DATA=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --infra-only)       INFRA_ONLY=true ;;
    --app-only)         APP_ONLY=true ;;
    --skip-sample-data) SKIP_SAMPLE=true ;;
    --seed-data)         SEED_DATA=true ;;
    --dry-run)          DRY_RUN=true ;;
    --help|-h)
      head -20 "$0" | grep "^#" | sed 's/^# *//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (use --help)"
      exit 1
      ;;
  esac
done

# --- Helpers ---
info()  { echo "=== $1"; }
step()  { echo "  → $1"; }
ok()    { echo "  ✓ $1"; }
fail()  { echo "  ✗ $1" >&2; exit 1; }

run_sql() {
  local file="$1"
  local desc="$2"
  if [ ! -f "$file" ]; then
    fail "SQL file not found: $file"
  fi
  step "$desc ($(basename "$file"))"
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] would execute: $file"
    return
  fi

  local result
  result=$(snow sql -f "$file" --enable-templating NONE 2>&1) || true
  echo "$result" | tail -5
}

# =============================================================================
# PHASE 0: Pre-flight checks
# =============================================================================
info "Phase 0: Pre-flight checks"

ok "Config loaded from deploy.config"
ok "  Database: ${DEAL_INTEL_DATABASE}"
ok "  App Schema: ${DEAL_INTEL_DATABASE}.${DEAL_INTEL_APP_SCHEMA}"
ok "  Query WH: ${DEAL_INTEL_QUERY_WH}"
ok "  User:     ${DEAL_INTEL_DEFAULT_USER}"

if ! command -v snow &> /dev/null; then
  fail "Snowflake CLI (snow) not found. Install: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation"
fi
ok "snow CLI found"

if [ "$DRY_RUN" = false ]; then
  CURRENT_ROLE=$(snow sql -q "SELECT CURRENT_ROLE()" --format json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['CURRENT_ROLE()'])" 2>/dev/null)
  if [ -z "$CURRENT_ROLE" ]; then
    fail "Cannot connect to Snowflake. Check your connection configuration."
  fi
  ok "Connected as role: $CURRENT_ROLE"

  # Validate we're running as DEAL_INTEL_ADMIN (or SYSADMIN which inherits it)
  if [ "$CURRENT_ROLE" != "DEAL_INTEL_ADMIN" ] && [ "$CURRENT_ROLE" != "SYSADMIN" ] && [ "$CURRENT_ROLE" != "ACCOUNTADMIN" ]; then
    echo "  ! WARNING: Connected as $CURRENT_ROLE. Expected DEAL_INTEL_ADMIN."
    echo "    Deploy scripts use DEAL_INTEL_ADMIN. Ensure your role can assume it."
  fi
else
  ok "[dry-run] Skipping connection check"
fi

# =============================================================================
# PHASE 1: Database Infrastructure
# =============================================================================
if [ "$APP_ONLY" = false ]; then
  info "Phase 1: Database Infrastructure"

  # Step 1: Foundation (database, schemas, warehouse, roles, grants)
  run_sql "${SQL_DIR}/01_foundation.sql" "Foundation: database, schemas, roles, grants"

  # Step 2: Ingestion (registry table, stage, procedures)
  run_sql "${SQL_DIR}/02_ingestion.sql" "Ingestion: registry, stage, procedures"

  # Step 3: Processing (document catalog, extraction results)
  run_sql "${SQL_DIR}/03_processing.sql" "Processing: document catalog, extractions"

  # Step 4: Telemetry (events, metrics)
  run_sql "${SQL_DIR}/04_telemetry.sql" "Telemetry: events, metrics tables"

  # Step 5: Intelligence (semantic view, search, agent)
  run_sql "${SQL_DIR}/05_intelligence.sql" "Intelligence: semantic view, search service, agent"

  # Step 6: Admin (config, queues, feedback)
  run_sql "${SQL_DIR}/06_admin.sql" "Admin: config, queues, feedback tables"

  # Step 6b: Seed classification labels (idempotent MERGE — always run so clean deploys are configured)
  run_sql "${SQL_DIR}/06b_seed_classification_labels.sql" "Seed: classification labels"

  # Step 7: Sample data (optional)
  if [ "$SKIP_SAMPLE" = false ]; then
    if [ -f "${SQL_DIR}/07_sample_data.sql" ]; then
      run_sql "${SQL_DIR}/07_sample_data.sql" "Sample data: demo documents"
    fi
  else
    step "Skipping sample data (--skip-sample-data)"
  fi

  # Step 9: Entitlements & RBAC
  run_sql "${SQL_DIR}/09_entitlements.sql" "Entitlements: user access control"
  run_sql "${SQL_DIR}/11_entitlement_roles.sql" "Entitlement roles & sector config"
  run_sql "${SQL_DIR}/12_multi_role_assignments.sql" "Multi-role assignments"

  # Step 13: Row Access Policy (entitlement-based LOB + DocType filtering)
  run_sql "${SQL_DIR}/13_row_access_policy.sql" "Row access policy: sector + DocType entitlements"

  ok "Database infrastructure complete"
fi

# =============================================================================
# PHASE 2: App Deployment
# =============================================================================
if [ "$INFRA_ONLY" = false ]; then
  info "Phase 2: App Deployment"

  if [ ! -f "${APP_DIR}/snowflake.yml" ]; then
    fail "snowflake.yml not found in ${APP_DIR}"
  fi

  # Generate .env for the app from deploy.config
  step "Generating app .env from deploy.config..."
  cat > "${APP_DIR}/.env" <<EOF
DEAL_INTEL_DATABASE=${DEAL_INTEL_DATABASE}
DEAL_INTEL_SERVICES_SCHEMA=${DEAL_INTEL_SERVICES_SCHEMA}
DEAL_INTEL_SEARCH_SVC=${DEAL_INTEL_SEARCH_SVC}
DEAL_INTEL_CORTEX_MODEL=${DEAL_INTEL_CORTEX_MODEL}
DEAL_INTEL_AGENT_NAME=${DEAL_INTEL_AGENT_NAME}
SNOWFLAKE_WAREHOUSE=${DEAL_INTEL_QUERY_WH}
NEXT_PUBLIC_DB_DISPLAY=${DEAL_INTEL_DATABASE}
EOF

  step "Deploying app via snow app deploy..."
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] would execute: cd ${APP_DIR} && snow app deploy --role ${DEAL_INTEL_ADMIN_ROLE}"
  else
    (cd "${APP_DIR}" && snow app deploy --role "${DEAL_INTEL_ADMIN_ROLE}") || fail "snow app deploy failed"
  fi
  ok "App deployed"
fi

# =============================================================================
# PHASE 3: Post-deploy grants
# =============================================================================
if [ "$INFRA_ONLY" = false ]; then
  info "Phase 3: Post-deploy grants"

  if [ -f "${SQL_DIR}/08_post_deploy_grants.sql" ]; then
    run_sql "${SQL_DIR}/08_post_deploy_grants.sql" "RBAC grants, caller privileges"
  fi

  # Caller grants for restricted caller's rights (DEAL_INTEL_ADMIN owns the service)
  step "Applying caller grants to DEAL_INTEL_ADMIN..."
  if [ "$DRY_RUN" = false ]; then
    snow sql -q "USE ROLE DEAL_INTEL_ADMIN" 2>/dev/null || true
    snow sql -q "GRANT ALL CALLER PRIVILEGES ON DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL SCHEMAS IN DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL TABLES IN DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL VIEWS IN DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL DYNAMIC TABLES IN DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL STAGES IN DATABASE ${DEAL_INTEL_DATABASE} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL CALLER PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL SCHEMAS IN DATABASE SNOWFLAKE TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT INHERITED CALLER USAGE ON ALL FUNCTIONS IN DATABASE SNOWFLAKE TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT CALLER USAGE ON AGENT ${DEAL_INTEL_DATABASE}.${DEAL_INTEL_SERVICES_SCHEMA}.${DEAL_INTEL_AGENT_NAME} TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
    snow sql -q "GRANT ALL CALLER PRIVILEGES ON SEMANTIC VIEW ${DEAL_INTEL_DATABASE}.${DEAL_INTEL_SERVICES_SCHEMA}.DOCUMENT_ANALYTICS_SV TO ROLE ${DEAL_INTEL_ADMIN_ROLE}" 2>/dev/null || true
  fi
  ok "Caller grants applied to ${DEAL_INTEL_ADMIN_ROLE}"

  # Grant roles to the default user
  step "Granting roles to ${DEAL_INTEL_DEFAULT_USER}..."
  if [ "$DRY_RUN" = false ]; then
    snow sql -q "USE ROLE SECURITYADMIN" 2>/dev/null || true
    snow sql -q "GRANT ROLE ${DEAL_INTEL_ADMIN_ROLE} TO USER ${DEAL_INTEL_DEFAULT_USER}" 2>/dev/null || true
    snow sql -q "GRANT ROLE ${DEAL_INTEL_USER_ROLE} TO USER ${DEAL_INTEL_DEFAULT_USER}" 2>/dev/null || true
    snow sql -q "USE ROLE DEAL_INTEL_ADMIN" 2>/dev/null || true
  fi
  ok "Roles granted to ${DEAL_INTEL_DEFAULT_USER}"
fi

# =============================================================================
# PHASE 4: Verification
# =============================================================================
info "Phase 4: Verification"

if [ "$DRY_RUN" = true ]; then
  echo "    [dry-run] would run verification queries"
else
  step "Checking database objects..."
  snow sql -q "SELECT COUNT(*) AS registry_rows FROM ${DEAL_INTEL_DATABASE}.DATA.ingestion_registry" 2>/dev/null && ok "ingestion_registry exists" || echo "  ! ingestion_registry missing"
  snow sql -q "SELECT COUNT(*) AS catalog_rows FROM ${DEAL_INTEL_DATABASE}.DATA.document_catalog" 2>/dev/null && ok "document_catalog exists" || echo "  ! document_catalog missing"

  step "Checking search service..."
  snow sql -q "SHOW CORTEX SEARCH SERVICES IN ${DEAL_INTEL_DATABASE}.SERVICES" 2>/dev/null && ok "Search service configured" || echo "  ! Search service missing"

  step "Checking agent..."
  snow sql -q "SHOW AGENTS IN ${DEAL_INTEL_DATABASE}.SERVICES" 2>/dev/null && ok "Agent exists" || echo "  ! Agent missing"

  if [ "$APP_ONLY" = true ] || [ "$INFRA_ONLY" = false ]; then
    step "Checking app status..."
    snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('${DEAL_INTEL_DATABASE}.${DEAL_INTEL_APP_SCHEMA}.${DEAL_INTEL_APP_NAME}')" 2>/dev/null && ok "App service running" || echo "  ! App service not found"
  fi

  step "Checking database ownership..."
  snow sql -q "SHOW DATABASES LIKE '${DEAL_INTEL_DATABASE}'" --format json 2>/dev/null | python3 -c "
import sys, json
rows = json.load(sys.stdin)
if rows:
    owner = rows[0].get('owner', 'unknown')
    print(f'    Owner: {owner}')
    if owner == '${DEAL_INTEL_ADMIN_ROLE}':
        print('  ✓ Correct: owned by ${DEAL_INTEL_ADMIN_ROLE}')
    else:
        print(f'  ! WARNING: owned by {owner}, expected ${DEAL_INTEL_ADMIN_ROLE}')
" 2>/dev/null || echo "  ! Could not verify ownership"
fi

# =============================================================================
echo ""
info "Deployment complete"
echo ""
echo "  Config:    deploy.config"
echo "  User:      ${DEAL_INTEL_DEFAULT_USER}"
echo "  Database:  ${DEAL_INTEL_DATABASE} (owned by ${DEAL_INTEL_ADMIN_ROLE})"
echo ""
echo "  To find your app URL, run:"
echo "    snow app status"
echo ""
echo "  To tear down: ./undeploy.sh"
echo ""
