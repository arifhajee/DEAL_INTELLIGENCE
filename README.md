# DEAL_INTEL: Infrastructure PE Document Intelligence

Deal document intelligence for infrastructure private equity, powered by Snowflake Cortex AI. Ingests deal documents (IC memos, term sheets, DD reports, LP reports, etc.), classifies them with AI, extracts structured deal attributes, and provides natural language search, analytics, and a review workflow.

## Features

### Built and Deployed

| Feature | Description |
|---------|-------------|
| **AI Pipeline** | Parse (AI_PARSE_DOCUMENT) → Classify (AI_CLASSIFY) → Extract (AI_EXTRACT) → Dynamic Table catalog |
| **Natural Language Search** | Cortex Search hybrid retrieval with semantic + keyword ranking |
| **Intra-Document Search** | Scope search to a single document using page-level Cortex Search |
| **Conversational Agent** | Cortex Agent routes between document search, page search, and analytics |
| **Page Citations** | Agent cites `[filename, p.N]` — clickable links in chat |
| **Document Detail** | 4-tab view: Attributes (inline editing), History, Related, Raw Text |
| **Review Queue** | Entitlement-scoped low-confidence review with Approve/Skip/Correct actions |
| **Inline Corrections** | Click any extracted field to correct it; pending corrections shown with badge |
| **Extraction Test Lab** | Pin staged files and run on-demand parse/classify/extract with full pipeline (Parse → Classify sector → Resolve Schema → Extract) |
| **Multi-Role Entitlements** | Users assigned to multiple roles; effective access = union of all roles |
| **Sector-Scoped Access** | Investor Relations sees only IR docs; Deal Team sees sourcing/DD/transaction docs |
| **Download Control** | Per-role `canDownload` flag; enforced server-side with audit logging |
| **CSV Export** | Export filtered document catalog with entitlement enforcement |
| **Bulk Reprocess** | Filter-based document selector with status/sector/type filters and requeue with confirmation |
| **Analytics** | Cortex Analyst for natural language portfolio queries with SQL view |
| **Dark/Light/System Theme** | Full dark mode with CSS variables, system preference detection, and flash prevention |
| **Classification Labels CRUD** | Dynamic category management — create, rename, delete categories and toggle labels |
| **Investment Sectors CRUD** | Configurable sectors with code, name, description, active toggle — drives AI classification dynamically |
| **User Profile** | Top-right dropdown with timezone, theme, and sign-out |
| **Admin Dashboard** | Pipeline health, ingestion registry, cost dashboard, configuration |

### Planned Phases

| Phase | Features |
|-------|---------|
| Phase 7 | Analytics trends, quality metrics, schema version control |
| Phase 8 | PII detection, document purge/archive, data lifecycle |
| Phase 9 | Batch corrections, annotations, notifications, in-app help |

## Quick Start

```bash
# Edit configuration
vim deploy.config

# Deploy everything (database + app + grants)
./deploy.sh          # macOS/Linux
.\deploy.ps1        # Windows

# Tear down (for clean re-deployment)
./undeploy.sh --confirm
```

## Repository Structure

```
deploy.config          Central configuration (all variables)
deploy.sh / .ps1       One-command deploy (bash / PowerShell)
undeploy.sh / .ps1     One-command teardown
sql/
  00_create_deploy_role.sql    Deploy role setup
  01_foundation.sql            Database, schemas, warehouses, roles, stages
  02_ingestion.sql             Ingestion registry + pipeline tasks
  03_processing.sql            AI processing procedures + document_catalog Dynamic Table
  04_telemetry.sql             Pipeline events, metrics views, alerts
  05_intelligence.sql          Cortex Search, Semantic View, Agent
  06_admin.sql                 Admin tables (config, corrections, bookmarks, etc.)
  07_sample_data.sql           4 representative sample documents
  08_post_deploy_grants.sql    Caller grants for SPCS App Runtime
  11_entitlement_roles.sql     Entitlement roles + lines_of_business
  12_multi_role_assignments.sql  User-role junction table
app/                   Next.js application (deployed to Snowflake App Runtime / SPCS)
  app/app/             Next.js App Router pages
  app/app/api/         API routes (all server-side, caller's rights)
  app/components/      Shared UI components
  app/lib/             Snowflake client, entitlements, utilities
  app/hooks/           React hooks (useRole, RoleProvider)
docs/
  API_REFERENCE.md     Stored procedures, Cortex services, API routes
  DEPLOYMENT_GUIDE.md  Full setup + troubleshooting guide
  USER_STORIES.md      All user stories with implementation status
  DATA_DICTIONARY.md   Table and view column reference
  OPERATIONS_GUIDE.md  Day-to-day operations
```

## Architecture

```
source system / Document Storage
  └─► @deal_documents_stage (Snowflake Internal Stage)
        └─► task_01_register_files (every 15 min)
              └─► ingestion_registry
                    └─► task_02_parse     (AI_PARSE_DOCUMENT)
                          └─► parsed_documents
                                └─► task_03_classify  (AI_CLASSIFY)
                                      └─► classified_documents
                                            └─► task_04_extract  (AI_EXTRACT)
                                                  └─► document_attributes
                                                        └─► document_catalog (Dynamic Table, 1h lag)
                                                              ├─► deal_search_svc (Cortex Search, document-level)
                                                              ├─► deal_page_search_svc (Cortex Search, page-level)
                                                              └─► deal_analytics_sv (Semantic View / Cortex Analyst)

Next.js App (Snowflake App Runtime / SPCS)
  ├─ /                  Dashboard (pipeline health, recent docs, onboarding)
  ├─ /search            Natural language + filtered document search
  ├─ /chat              Cortex Agent conversational Q&A with page citations
  ├─ /analytics         Cortex Analyst natural language analytics
  ├─ /documents         Document Browser with CSV export
  ├─ /documents/detail  4-tab document detail with inline corrections
  ├─ /review            Entitlement-scoped review queue
  ├─ /saved             Saved searches + bookmarks
  └─ /admin/*           Pipeline, registry, schema, labels, sectors, cost, config, users
```

## Authentication

The app uses **Snowflake App Runtime caller's rights authentication** — no credentials are stored in the app. Every API call executes as the logged-in Snowflake user via the `sf-context-current-user-token` header injected by SPCS.

Access control has two layers:
1. **Snowflake RBAC** — `IS_ROLE_IN_SESSION('DEAL_INTEL_ADMIN')` checked on every request
2. **App-managed entitlements** — sector, document type, and menu access from `ADMIN.user_role_assignments` + `ADMIN.entitlement_roles`

## Documentation

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) — full setup + troubleshooting
- [API Reference](docs/API_REFERENCE.md) — stored procedures, Cortex services, REST routes, entitlements
- [User Stories](docs/USER_STORIES.md) — all user stories with implementation status
- [Data Dictionary](docs/DATA_DICTIONARY.md) — all tables, views, and columns
- [Operations Guide](docs/OPERATIONS_GUIDE.md) — day-to-day operations

*Last updated: August 2026 — Phases 1–6 complete, plus theme, CRUD labels/sectors, Test Lab pins, reprocess filters*
