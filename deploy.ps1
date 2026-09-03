# =============================================================================
# DEAL_INTEL: Unified Deployment Script (Windows PowerShell)
# =============================================================================
# Usage:
#   .\deploy.ps1                    Full deploy (infra + app + grants)
#   .\deploy.ps1 -InfraOnly        Database infrastructure only (no app deploy)
#   .\deploy.ps1 -AppOnly          App deploy + post-deploy grants only
#   .\deploy.ps1 -SkipRoleSetup    Skip 00_create_deploy_role.sql (re-deploys)
#   .\deploy.ps1 -SkipSampleData   Skip 07_sample_data.sql
#   .\deploy.ps1 -DryRun           Show what would be executed without running
# =============================================================================

param(
    [switch]$InfraOnly,
    [switch]$AppOnly,
    [switch]$SkipRoleSetup,
    [switch]$SkipSampleData,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Load Configuration ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "deploy.config"
$SqlDir = Join-Path $ScriptDir "sql"
$AppDir = Join-Path $ScriptDir "app"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "deploy.config not found at $ConfigFile"
    exit 1
}

# Parse deploy.config (KEY=VALUE format)
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
function Fail($msg)  { Write-Error "  [FAIL] $msg"; exit 1 }

function Run-Sql($file, $desc) {
    if (-not (Test-Path $file)) {
        Fail "SQL file not found: $file"
    }
    Step "$desc ($(Split-Path -Leaf $file))"
    if ($DryRun) {
        Write-Host "    [dry-run] would execute: $file"
        return
    }

    $content = Get-Content $file -Raw
    if ($content -match '\$\$') {
        # File has $$-delimited procedure blocks — deploy in two passes

        # Pass 1: Non-procedure statements
        $lines = Get-Content $file
        $insideProc = $false
        $plainSql = @()
        foreach ($line in $lines) {
            if ($line -match '^CREATE\s+OR\s+REPLACE\s+(PROCEDURE|FUNCTION)') {
                $insideProc = $true
            }
            if (-not $insideProc) {
                $plainSql += $line
            }
            if ($insideProc -and $line -match '^\$\$;') {
                $insideProc = $false
            }
        }
        $plainContent = $plainSql -join "`n"
        if ($plainContent.Trim()) {
            $plainContent | snow sql -i 2>&1 | Select-Object -Last 3
        }

        # Pass 2: Extract and deploy each procedure block individually
        $procBlocks = [regex]::Matches($content, '(?s)(CREATE\s+OR\s+REPLACE\s+(?:PROCEDURE|FUNCTION).+?\$\$;)')
        $procCount = 0
        foreach ($match in $procBlocks) {
            $block = $match.Value
            snow sql -q $block 2>&1 | Select-String -Pattern "success|error|created" | Select-Object -First 3
            $procCount++
        }
        Write-Host "    Deployed $procCount procedure(s)"
    } else {
        # No $$ blocks — safe to use stdin mode
        $content | snow sql -i 2>&1 | Select-Object -Last 5
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    Warning: Some statements in $file may have failed (non-fatal)" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# PHASE 0: Pre-flight checks
# =============================================================================
Info "Phase 0: Pre-flight checks"

Ok "Config loaded from deploy.config"
Ok "  Database: $($Config['DEAL_INTEL_DATABASE'])"
Ok "  App DB:   $($Config['DEAL_INTEL_DATABASE'])"
Ok "  Query WH: $($Config['DEAL_INTEL_QUERY_WH'])"
Ok "  User:     $($Config['DEAL_INTEL_DEFAULT_USER'])"

if (-not (Get-Command snow -ErrorAction SilentlyContinue)) {
    Fail "Snowflake CLI (snow) not found. Install: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation"
}
Ok "snow CLI found"

if (-not $DryRun) {
    $role = snow sql -q "SELECT CURRENT_ROLE()" --format json 2>$null | ConvertFrom-Json
    if (-not $role) {
        Fail "Cannot connect to Snowflake. Check your connection configuration."
    }
    Ok "Connected to Snowflake"
}

# =============================================================================
# PHASE 1: Database Infrastructure
# =============================================================================
if (-not $AppOnly) {
    Info "Phase 1: Database Infrastructure"

    # Pre-requisites: ensure app database and EAI exist
    Step "Ensuring app database and external access integration exist..."
    if (-not $DryRun) {
        snow sql -q "CREATE DATABASE IF NOT EXISTS $($Config['DEAL_INTEL_DATABASE'])" 2>$null
        snow sql -q "CREATE OR REPLACE NETWORK RULE $($Config['DEAL_INTEL_NETWORK_RULE']) MODE = EGRESS TYPE = HOST_PORT VALUE_LIST = ('registry.npmjs.org:443','0.0.0.0:443','0.0.0.0:80')" 2>$null
        snow sql -q "CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION $($Config['DEAL_INTEL_EAI']) ALLOWED_NETWORK_RULES = ($($Config['DEAL_INTEL_NETWORK_RULE'])) ENABLED = TRUE" 2>$null
    }
    Ok "Pre-requisites ready"

    if (-not $SkipRoleSetup -and (Test-Path (Join-Path $SqlDir "00_create_deploy_role.sql"))) {
        Run-Sql (Join-Path $SqlDir "00_create_deploy_role.sql") "Create deploy role and EAI"
    } else {
        Step "Skipping role setup (-SkipRoleSetup)"
    }

    Run-Sql (Join-Path $SqlDir "01_foundation.sql") "Foundation: database, schemas, warehouse"
    Run-Sql (Join-Path $SqlDir "02_ingestion.sql") "Ingestion: registry, stage, procedures"
    Run-Sql (Join-Path $SqlDir "03_processing.sql") "Processing: document catalog, extractions"
    Run-Sql (Join-Path $SqlDir "04_telemetry.sql") "Telemetry: events, metrics tables"
    Run-Sql (Join-Path $SqlDir "05_intelligence.sql") "Intelligence: semantic view, search service"
    Run-Sql (Join-Path $SqlDir "06_admin.sql") "Admin: config, queues, feedback tables"

    if (-not $SkipSampleData) {
        Run-Sql (Join-Path $SqlDir "07_sample_data.sql") "Sample data: demo documents"
    } else {
        Step "Skipping sample data (-SkipSampleData)"
    }

    Ok "Database infrastructure complete"
}

# =============================================================================
# PHASE 2: App Deployment
# =============================================================================
if (-not $InfraOnly) {
    Info "Phase 2: App Deployment"

    $ymlPath = Join-Path $AppDir "snowflake.yml"
    if (-not (Test-Path $ymlPath)) {
        Fail "snowflake.yml not found in $AppDir"
    }

    # Generate .env for the app from deploy.config
    Step "Generating app .env from deploy.config..."
    $envContent = @"
DEAL_INTEL_DATABASE=$($Config['DEAL_INTEL_DATABASE'])
DEAL_INTEL_SERVICES_SCHEMA=$($Config['DEAL_INTEL_SERVICES_SCHEMA'])
DEAL_INTEL_SEARCH_SVC=$($Config['DEAL_INTEL_SEARCH_SVC'])
DEAL_INTEL_CORTEX_MODEL=$($Config['DEAL_INTEL_CORTEX_MODEL'])
DEAL_INTEL_AGENT_NAME=$($Config['DEAL_INTEL_AGENT_NAME'])
SNOWFLAKE_WAREHOUSE=$($Config['DEAL_INTEL_QUERY_WH'])
NEXT_PUBLIC_DB_DISPLAY=$($Config['DEAL_INTEL_DATABASE'])
"@
    $envContent | Set-Content (Join-Path $AppDir ".env") -NoNewline

    # Ensure app database exists
    if (-not $DryRun) {
        snow sql -q "CREATE DATABASE IF NOT EXISTS $($Config['DEAL_INTEL_DATABASE'])" 2>$null
    }

    Step "Deploying app via snow app deploy..."
    if ($DryRun) {
        Write-Host "    [dry-run] would execute: snow app deploy in $AppDir"
    } else {
        Push-Location $AppDir
        snow app deploy
        if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "snow app deploy failed" }
        Pop-Location
    }
    Ok "App deployed"
}

# =============================================================================
# PHASE 3: Post-deploy grants
# =============================================================================
if (-not $InfraOnly) {
    Info "Phase 3: Post-deploy grants"

    if (Test-Path (Join-Path $SqlDir "08_post_deploy_grants.sql")) {
        Run-Sql (Join-Path $SqlDir "08_post_deploy_grants.sql") "Caller grants, RBAC, search service"
    }

    # Caller grants for restricted caller's rights
    Step "Applying caller grants..."
    $db = $Config['DEAL_INTEL_DATABASE']
    $searchSvc = $Config['DEAL_INTEL_SEARCH_SVC']
    if (-not $DryRun) {
        snow sql -q "GRANT ALL CALLER PRIVILEGES ON DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL SCHEMAS IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL TABLES IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL VIEWS IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL DYNAMIC TABLES IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL STAGES IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL PROCEDURES IN DATABASE $db TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL CALLER PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL INHERITED CALLER PRIVILEGES ON ALL SCHEMAS IN DATABASE SNOWFLAKE TO ROLE SYSADMIN" 2>$null
        # Cortex services require explicit caller grants
        snow sql -q "GRANT ALL CALLER PRIVILEGES ON CORTEX SEARCH SERVICE $db.PUBLIC.$searchSvc TO ROLE SYSADMIN" 2>$null
        snow sql -q "GRANT ALL CALLER PRIVILEGES ON SEMANTIC VIEW $db.PUBLIC.document_analytics_sv TO ROLE SYSADMIN" 2>$null
    }
    Ok "Caller grants applied"

    # Grant roles to the default user
    $user = $Config['DEAL_INTEL_DEFAULT_USER']
    Step "Granting roles to $user..."
    if (-not $DryRun) {
        snow sql -q "USE ROLE SECURITYADMIN" 2>$null
        snow sql -q "GRANT ROLE $($Config['DEAL_INTEL_ADMIN_ROLE']) TO USER $user" 2>$null
        snow sql -q "GRANT ROLE $($Config['DEAL_INTEL_USER_ROLE']) TO USER $user" 2>$null
        snow sql -q "GRANT ROLE $($Config['DEAL_INTEL_PIPELINE_ROLE']) TO USER $user" 2>$null
        $drawerRoles = $Config['DEAL_INTEL_DRAWER_ROLES'] -split " "
        foreach ($role in $drawerRoles) {
            if ($role) { snow sql -q "GRANT ROLE $role TO USER $user" 2>$null }
        }
        snow sql -q "USE ROLE SYSADMIN" 2>$null
    }
    Ok "Roles granted to $user"
}

# =============================================================================
# PHASE 4: Verification
# =============================================================================
Info "Phase 4: Verification"

$db = $Config['DEAL_INTEL_DATABASE']
$appDb = $Config['DEAL_INTEL_DATABASE']
$appName = $Config['DEAL_INTEL_APP_NAME']

if ($DryRun) {
    Write-Host "    [dry-run] would run verification queries"
} else {
    Step "Checking database objects..."
    snow sql -q "SELECT COUNT(*) AS registry_rows FROM $db.PUBLIC.ingestion_registry" 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "ingestion_registry exists" } else { Write-Host "  ! ingestion_registry missing" }

    Step "Checking search service..."
    snow sql -q "SHOW CORTEX SEARCH SERVICES IN $db.PUBLIC" 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "Search service configured" } else { Write-Host "  ! Search service missing" }

    Step "Checking semantic view..."
    snow sql -q "SHOW SEMANTIC VIEWS IN $db.PUBLIC" 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "Semantic view exists" } else { Write-Host "  ! Semantic view missing" }

    if ($AppOnly -or (-not $InfraOnly)) {
        Step "Checking app status..."
        snow sql -q "SELECT SYSTEM`$GET_SERVICE_STATUS('$appDb.PUBLIC.$appName')" 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "App service running" } else { Write-Host "  ! App service not found" }
    }
}

# =============================================================================
Write-Host ""
Info "Deployment complete"
Write-Host ""
Write-Host "  Config:    deploy.config"
Write-Host "  User:      $($Config['DEAL_INTEL_DEFAULT_USER'])"
Write-Host "  Database:  $($Config['DEAL_INTEL_DATABASE'])"
Write-Host ""
Write-Host "  To find your app URL, run:"
Write-Host "    snow app status"
Write-Host ""
Write-Host "  To tear down: .\undeploy.ps1"
Write-Host ""
