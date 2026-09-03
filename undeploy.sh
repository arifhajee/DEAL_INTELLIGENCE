#!/bin/bash
# =============================================================================
# DEAL_INTEL: Undeploy — removes ALL Snowflake objects for clean re-deployment
# =============================================================================
# Usage:
#   ./undeploy.sh              Full teardown (prompts for confirmation)
#   ./undeploy.sh --confirm    Skip confirmation prompt
#   ./undeploy.sh --keep-roles Keep roles intact (useful for quick re-deploy)
#   ./undeploy.sh --dry-run    Show what would be dropped without executing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/deploy.config"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: deploy.config not found at $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# --- Flags ---
CONFIRMED=false
KEEP_ROLES=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --confirm)     CONFIRMED=true ;;
    --keep-roles)  KEEP_ROLES=true ;;
    --dry-run)     DRY_RUN=true ;;
    --help|-h)
      head -12 "$0" | grep "^#" | sed 's/^# *//'
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

run_drop() {
  local sql="$1"
  local desc="$2"
  step "$desc"
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] $sql"
  else
    snow sql -q "$sql" 2>/dev/null || true
  fi
}

# --- Confirmation ---
if [ "$DRY_RUN" = false ] && [ "$CONFIRMED" = false ]; then
  echo ""
  echo "WARNING: This will DESTROY all DEAL_INTEL objects in Snowflake:"
  echo "  - Application service: ${DEAL_INTEL_DATABASE}.${DEAL_INTEL_APP_SCHEMA}.${DEAL_INTEL_APP_NAME}"
  echo "  - Database: ${DEAL_INTEL_DATABASE} (schemas: DATA, SERVICES, ADMIN, APP, TELEMETRY, APP_SERVICE)"
  echo "  - All tables, views, stages, procedures, tasks, search services"
  echo "  - Integration: ${DEAL_INTEL_EAI}"
  if [ "$KEEP_ROLES" = false ]; then
    echo "  - Roles: ${DEAL_INTEL_ADMIN_ROLE}, ${DEAL_INTEL_USER_ROLE}, ${DEAL_INTEL_PIPELINE_ROLE}"
  fi
  echo "  - Warehouse: ${DEAL_INTEL_PIPELINE_WH}"
  echo ""
  read -p "Type 'yes' to proceed: " answer
  if [ "$answer" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
info "Undeploying DEAL_INTEL"

# =============================================================================
# Phase 1: Drop Application Service
# =============================================================================
info "Phase 1: Application Service"
run_drop "DROP SERVICE IF EXISTS ${DEAL_INTEL_DATABASE}.${DEAL_INTEL_APP_SCHEMA}.${DEAL_INTEL_APP_NAME}" \
         "Drop app service ${DEAL_INTEL_APP_NAME}"

# =============================================================================
# Phase 2: Drop Cortex Services (before dropping the database)
# =============================================================================
info "Phase 2: Cortex Services"
run_drop "DROP CORTEX SEARCH SERVICE IF EXISTS ${DEAL_INTEL_DATABASE}.SERVICES.${DEAL_INTEL_SEARCH_SVC}" \
         "Drop search service ${DEAL_INTEL_SEARCH_SVC}"
run_drop "DROP SEMANTIC VIEW IF EXISTS ${DEAL_INTEL_DATABASE}.SERVICES.document_analytics_sv" \
         "Drop semantic view"
run_drop "DROP CORTEX AGENT IF EXISTS ${DEAL_INTEL_DATABASE}.SERVICES.deal_intelligence_agent" \
         "Drop cortex agent"

# =============================================================================
# Phase 3: Drop Databases (cascades all tables, views, stages, procs, tasks)
# =============================================================================
info "Phase 3: Databases"
run_drop "DROP DATABASE IF EXISTS ${DEAL_INTEL_DATABASE}" \
         "Drop database ${DEAL_INTEL_DATABASE} (all pipeline objects)"

# =============================================================================
# Phase 4: Drop Integration & Network Rule
# =============================================================================
info "Phase 4: Integration"
run_drop "DROP INTEGRATION IF EXISTS ${DEAL_INTEL_EAI}" \
         "Drop EAI ${DEAL_INTEL_EAI}"
run_drop "DROP NETWORK RULE IF EXISTS ${DEAL_INTEL_NETWORK_RULE}" \
         "Drop network rule ${DEAL_INTEL_NETWORK_RULE}"

# =============================================================================
# Phase 5: Drop Roles (unless --keep-roles)
# =============================================================================
if [ "$KEEP_ROLES" = false ]; then
  info "Phase 5: Roles"
  for role in $DEAL_INTEL_PIPELINE_ROLE $DEAL_INTEL_USER_ROLE $DEAL_INTEL_ADMIN_ROLE; do
    run_drop "DROP ROLE IF EXISTS $role" "Drop role $role"
  done
else
  info "Phase 5: Roles (skipped — --keep-roles)"
fi

# =============================================================================
# Phase 6: Drop Pipeline Warehouse and Query Warehouse
# =============================================================================
info "Phase 6: Warehouses & Compute Pool"
run_drop "DROP WAREHOUSE IF EXISTS ${DEAL_INTEL_PIPELINE_WH}" \
         "Drop pipeline warehouse ${DEAL_INTEL_PIPELINE_WH}"
if [ "$DEAL_INTEL_PIPELINE_WH" != "$DEAL_INTEL_QUERY_WH" ]; then
  run_drop "DROP WAREHOUSE IF EXISTS ${DEAL_INTEL_QUERY_WH}" \
           "Drop query warehouse ${DEAL_INTEL_QUERY_WH}"
fi

run_drop "DROP COMPUTE POOL IF EXISTS ${DEAL_INTEL_COMPUTE_POOL}" \
         "Drop compute pool ${DEAL_INTEL_COMPUTE_POOL}"

# =============================================================================
echo ""
info "Undeploy complete"
echo ""
echo "  All DEAL_INTEL objects have been removed."
echo "  To redeploy: ./deploy.sh"
echo ""
