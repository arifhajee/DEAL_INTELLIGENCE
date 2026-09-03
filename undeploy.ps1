# =============================================================================
# DEAL_INTEL: Undeploy — removes ALL Snowflake objects (Windows PowerShell)
# =============================================================================
# Usage:
#   .\undeploy.ps1              Full teardown (prompts for confirmation)
#   .\undeploy.ps1 -Confirm     Skip confirmation prompt
#   .\undeploy.ps1 -KeepRoles   Keep roles intact (useful for quick re-deploy)
#   .\undeploy.ps1 -DryRun      Show what would be dropped without executing
# =============================================================================

param(
    [switch]$Confirm,
    [switch]$KeepRoles,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Load Configuration ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "deploy.config"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "deploy.config not found at $ConfigFile"
    exit 1
}

# Parse deploy.config
$Config = @{}
Get-Content $ConfigFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $Config[$parts[0].Trim()] = $parts[1].Trim().Trim('"')
        }
    }
}

# --- Helpers ---
function Info($msg)  { Write-Host "=== $msg" -ForegroundColor Cyan }
function Step($msg)  { Write-Host "  -> $msg" }
function Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }

function Run-Drop($sql, $desc) {
    Step $desc
    if ($DryRun) {
        Write-Host "    [dry-run] $sql"
    } else {
        snow sql -q $sql 2>$null
        # Ignore errors (object may not exist)
    }
}

# --- Confirmation ---
if (-not $DryRun -and -not $Confirm) {
    Write-Host ""
    Write-Host "WARNING: This will DESTROY all DEAL_INTEL objects in Snowflake:" -ForegroundColor Red
    Write-Host "  - Application service: $($Config['DEAL_INTEL_DATABASE']).PUBLIC.$($Config['DEAL_INTEL_APP_NAME'])"
    Write-Host "  - Database: $($Config['DEAL_INTEL_DATABASE']) (schemas: DATA, SERVICES, ADMIN, APP, TELEMETRY, APP_SERVICE)"
    Write-Host "  - All tables, views, stages, procedures, tasks, search services"
    Write-Host "  - Integration: $($Config['DEAL_INTEL_EAI'])"
    if (-not $KeepRoles) {
        Write-Host "  - Roles: $($Config['DEAL_INTEL_DEPLOY_ROLE']), $($Config['DEAL_INTEL_ADMIN_ROLE']), $($Config['DEAL_INTEL_USER_ROLE']), $($Config['DEAL_INTEL_PIPELINE_ROLE'])"
    }
    Write-Host "  - Warehouse: $($Config['DEAL_INTEL_PIPELINE_WH'])"
    Write-Host ""
    $answer = Read-Host "Type 'yes' to proceed"
    if ($answer -ne "yes") {
        Write-Host "Aborted."
        exit 0
    }
}

Write-Host ""
Info "Undeploying DEAL_INTEL"

$db = $Config['DEAL_INTEL_DATABASE']
$appDb = $Config['DEAL_INTEL_DATABASE']
$appName = $Config['DEAL_INTEL_APP_NAME']
$searchSvc = $Config['DEAL_INTEL_SEARCH_SVC']
$eai = $Config['DEAL_INTEL_EAI']
$netRule = $Config['DEAL_INTEL_NETWORK_RULE']
$pipelineWh = $Config['DEAL_INTEL_PIPELINE_WH']
$queryWh = $Config['DEAL_INTEL_QUERY_WH']

# =============================================================================
# Phase 1: Drop Application Service
# =============================================================================
Info "Phase 1: Application Service"
Run-Drop "DROP SERVICE IF EXISTS $appDb.PUBLIC.$appName" "Drop app service $appName"

# =============================================================================
# Phase 2: Drop Cortex Services
# =============================================================================
Info "Phase 2: Cortex Services"
Run-Drop "DROP CORTEX SEARCH SERVICE IF EXISTS $db.SERVICES.$searchSvc" "Drop search service $searchSvc"
Run-Drop "DROP SEMANTIC VIEW IF EXISTS $db.SERVICES.document_analytics_sv" "Drop semantic view"
Run-Drop "DROP CORTEX AGENT IF EXISTS $db.SERVICES.doc_intelligence_agent" "Drop cortex agent"

# =============================================================================
# Phase 3: Drop Databases
# =============================================================================
Info "Phase 3: Databases"
Run-Drop "DROP DATABASE IF EXISTS $appDb" "Drop database $appDb (app + workspace)"
Run-Drop "DROP DATABASE IF EXISTS $db" "Drop database $db (all pipeline objects)"

# =============================================================================
# Phase 4: Drop Integration & Network Rule
# =============================================================================
Info "Phase 4: Integration"
Run-Drop "DROP INTEGRATION IF EXISTS $eai" "Drop EAI $eai"
Run-Drop "DROP NETWORK RULE IF EXISTS $netRule" "Drop network rule $netRule"

# =============================================================================
# Phase 5: Drop Roles
# =============================================================================
if (-not $KeepRoles) {
    Info "Phase 5: Roles"
    $allRoles = @()
    $allRoles += $Config['DEAL_INTEL_PIPELINE_ROLE']
    $allRoles += $Config['DEAL_INTEL_USER_ROLE']
    $allRoles += $Config['DEAL_INTEL_ADMIN_ROLE']
    $allRoles += $Config['DEAL_INTEL_DEPLOY_ROLE']
    foreach ($role in $allRoles) {
        if ($role) {
            Run-Drop "DROP ROLE IF EXISTS $role" "Drop role $role"
        }
    }
} else {
    Info "Phase 5: Roles (skipped — -KeepRoles)"
}

# =============================================================================
# Phase 6: Drop Pipeline Warehouse
# =============================================================================
Info "Phase 6: Pipeline Warehouse"
if ($pipelineWh -ne $queryWh) {
    Run-Drop "DROP WAREHOUSE IF EXISTS $pipelineWh" "Drop pipeline warehouse $pipelineWh"
} else {
    Step "Pipeline WH = Query WH ($queryWh) — not dropping shared warehouse"
}

# =============================================================================
Write-Host ""
Info "Undeploy complete"
Write-Host ""
Write-Host "  All DEAL_INTEL objects have been removed."
Write-Host "  To redeploy: .\deploy.ps1"
Write-Host ""
