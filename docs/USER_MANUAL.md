# DealIntel User Manual

**Document Intelligence Platform for Infrastructure Investments**
*Powered by Snowflake Cortex AI*

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Overview Dashboard](#overview-dashboard)
3. [Document Browser](#document-browser)
4. [Document Search](#document-search)
5. [Review Queue](#review-queue)
6. [Deal Intelligence Agent](#doc-intelligence-agent)
7. [Portfolio Analytics](#portfolio-analytics)
8. [Saved Items](#saved-items)
9. [Document Detail View](#document-detail-view)
10. [Administration](#administration)
    - [Pipeline Management](#pipeline-management)
    - [Ingestion Registry](#ingestion-registry)
    - [Quality & Feedback](#quality--feedback)
    - [Cost Dashboard](#cost-dashboard)
    - [Extraction Schema & Test Lab](#extraction-schema--test-lab)
    - [Classification Labels](#classification-labels)
    - [Investment Sectors](#lines-of-business)
    - [Notifications](#notifications)
    - [Configuration](#configuration)
    - [Audit Log](#audit-log)
    - [User Management](#user-management)
11. [Help & Tips](#help--tips)

---

## Getting Started

DealIntel is an AI-powered document intelligence platform built for infrastructure PE operations. It automatically parses, classifies, and extracts structured data from deal documents including investments, deals, side letters, binders, certificates, and correspondence.

### Access & Authentication

Access to DealIntel is controlled through Snowflake role-based entitlements:

- **DEAL_INTEL_USER** — Standard user access (documents, search, review, analytics)
- **DEAL_INTEL_ADMIN** — Full access including all administration features

Your visibility into documents is determined by your assigned role's permissions:
- **Sector (sector) access** — Controls which sectors' documents you can see
- **Document Type access** — Controls which document types are visible
- **Page access** — Controls which application pages appear in your sidebar

### Navigation

The left sidebar provides access to all features. It is organized into two sections:

**Main Navigation:**
| Page | Description |
|------|-------------|
| Overview | Pipeline health and recent activity |
| Document Browser | Browse and filter all indexed documents |
| Document Search | AI-powered content search |
| Review Queue | Approve or correct low-confidence documents |
| Deal Intelligence | Conversational AI agent for document questions |
| Portfolio Analytics | Charts, KPIs, and natural language data queries |
| Saved Items | Your saved searches and bookmarked documents |
| Help | In-app documentation and tips |

**Administration** (visible to admins):
| Section | Pages |
|---------|-------|
| Operations | Pipeline Management, Ingestion Registry, Quality & Feedback, Cost Dashboard |
| AI Config | Extraction Schema, Classification Labels, Investment Sectors |
| Management | Notifications, Configuration, Audit Log, User Management |

The Review Queue badge in the sidebar shows the count of documents pending review.

---

## Overview Dashboard

**Path:** `/` (Home)

The Overview page provides an at-a-glance summary of your document intelligence platform.

### What You See

- **Hero Banner** — Platform title with quick-access buttons to Search Documents and Ask a Question
- **Metrics Cards** — Four key indicators:
  - **Total Indexed** — Documents fully processed and available for search
  - **In Queue** — Documents currently being processed
  - **Failed** — Documents that encountered processing errors
  - **Total Seen** — All documents ever registered by the platform
- **Quick Questions** — Pre-built questions you can click to instantly query the AI agent:
  - "What exclusions apply to our Digital Infrastructure investments?"
  - "How many cyber deals are open this year?"
  - "Find investment memos from the last 90 days"
  - "Which investments expire in the next 60 days?"
- **Recently Indexed** — The last 8 documents processed, showing source folder, document type, and format

### First-Run Onboarding (Admin Only)

If no documents have been indexed yet, admins see a setup banner with links to:
- Configure the ingestion pipeline
- Set up user access and roles

---

## Document Browser

**Path:** `/documents`

The Document Browser is your primary interface for browsing, filtering, and managing all indexed documents.

### Filtering Documents

Use the filter bar at the top to narrow results:

- **Document Type** — Dropdown to filter by classification (e.g., Policy, Claim, Endorsement)
- **Sector** — Dropdown to filter by sector (e.g., Digital Infrastructure, Cyber, Energy Transition, Marine)
- **Text Search** — Search across target company, sector, fund name, and content
- **Needs Review Only** — Checkbox to show only documents flagged for human review

The total document count updates as you apply filters.

### Document Table

The table displays documents with these columns:

| Column | Description |
|--------|-------------|
| Checkbox | Select documents for batch actions |
| Type | Document classification (links to detail page) |
| Insured | Insured party name |
| sector | Sector (color-coded badge) |
| Format | File format (PDF, TIFF, DOCX, etc.) |
| Status | Processing status |
| Confidence | AI confidence score (green ≥85%, amber ≥70%, red <70%) |
| Effective Date | Policy effective date |
| Expiry Date | Policy expiration date |
| Policy # | Policy number |

### Viewing Document Details

Click any row to open the **side detail panel** showing:

- Document type and warning indicators (low confidence, PII detected)
- Full metadata: Insured, Carrier, sector, Coverage Form, Policy #, Claim #, dates, Status, Pages, Format, Confidence
- Document summary
- **View Document** button to open the original file preview

### Correcting Attributes

From the side panel, scroll to "Correct an Attribute":

1. Select the field to correct from the dropdown
2. Enter the correct value
3. Click **Submit Correction**

Correctable fields include: Insured Name, Carrier, Document Type, Policy Number, Claim Number, Sector, Coverage Form, Status, Effective Date, Expiration Date, Retroactive Date.

### Batch Actions

1. Select documents using row checkboxes
2. A floating action bar appears showing the selection count
3. Available actions: **Archive Selected**
4. Click Apply to execute or Clear to deselect

### Export

Click the **Export CSV** button in the header to download the current filtered view as a CSV file.

### Pagination

Results display 50 per page. Use Previous/Next buttons to navigate.

---

## Document Search

**Path:** `/search`

Document Search uses Snowflake Cortex Search to find documents by their content using natural language queries.

### Performing a Search

1. Type your query in the search bar (e.g., "Digital Infrastructure deals with cyber exclusions")
2. Click **Search** or press Enter
3. Results appear ranked by relevance with matching snippets highlighted

### Using Filters

Click the **Filters** toggle to expand additional options:

- **Sector** — Filter results to specific sectors
- **Document Type** — Filter by classification
- **Format** — Filter by file format (PDF, TIFF, etc.)
- **Status** — Filter by document status
- **Max Results** — Control result count (10, 20, 50, or 100)

### Suggested Searches

When the search bar is empty, suggested searches are displayed:
- Digital Infrastructure Deals
- Cyber IC Presentation
- Investment Memos
- Energy Transition Term Sheets
- Redeal Certs
- Expiring Investments

Click any suggestion to run that search instantly.

### Working with Results

Each result shows:

- Document type with format badge
- Insured/Party name
- sector (color badge)
- Status (color badge)
- Matching content snippet

**Actions per result:**
- **Thumbs Up/Down** — Provide relevance feedback to improve future searches
- **Bookmark** — Save the document for quick access later (appears in Saved Items)

### Result Detail Panel

Click any result to open the detail panel showing:
- Full metadata grid (Insured, Carrier, Coverage Form, dates, Limits, Policy #, Claim #, Confidence)
- Document summary
- Additional matching excerpts with page numbers
- Links to the full document detail page and file preview

### Saving Searches

1. Click the **Save** button (floppy disk icon) next to the search bar
2. Enter a name for the search
3. Choose visibility:
   - **Just Me** — Only you can see this saved search
   - **My Role** — All users with your role can see it
   - **Everyone** — All platform users can see it
4. Click **Save**

Saved searches preserve your query and all active filters for one-click re-use.

### Scoped Search

When navigating to search from a specific document's Raw Text tab, search can be scoped to a single file. A banner shows the scoped filename with a "Clear scope" button to return to global search.

---

## Review Queue

**Path:** `/review`

The Review Queue surfaces documents that need human review — typically those with low AI confidence scores or competing classification candidates.

### Understanding the Queue

- **Scope Display** — Shows your sector and document type access (you only see documents within your entitlements)
- **Progress Bar** — Visual indicator showing Pending / Approved / Skipped counts with completion percentage

### Status Tabs

Switch between views:
- **Pending** — Documents awaiting review (with count badge)
- **Approved** — Documents you've already approved
- **Skipped** — Documents you've skipped
- **All** — Complete list regardless of status

### Document Cards

Each card in the queue displays:

- Filename and source folder
- Document type badge
- sector badge
- **Confidence bar** — Visual indicator with color coding:
  - Green (≥75%) — High confidence
  - Amber (≥50%) — Medium confidence
  - Red (<50%) — Low confidence
- **Review reason** — Why this document was flagged (e.g., "Low confidence: 62%")
- **Also considered** — Alternative document types the AI considered (helps you decide if the AI got it right)
- Key metadata: Insured, Policy #, Claim #

### Taking Action

Three actions are available for each pending document:

1. **Approve** (green checkmark) — Confirms the AI's classification is correct. The document exits the queue.

2. **Skip** (gray button) — Removes the document from your queue without approving or correcting. Use when you're unsure or the document isn't in your area.

3. **Correct** (amber button with dropdown) — Opens a dropdown showing alternative document types. Select the correct type to:
   - Submit the correction
   - Auto-approve the document with the corrected classification
   - The "Open detail for manual correction..." link at the bottom opens the full detail page for complex corrections

### Pagination

Results display 20 per page with Previous/Next navigation.

---

## Deal Intelligence Agent

**Path:** `/chat`

The Deal Intelligence Agent is a conversational AI interface powered by Snowflake Cortex Agent. It can search documents, read content, query portfolio data, and answer questions that span both unstructured documents and structured analytics.

### Starting a Conversation

Type your question in the input field and press Enter or click Send. Example questions:

- "What exclusions apply to our Digital Infrastructure investments?"
- "How many cyber deals are open this year?"
- "Find investment memos from the last 90 days"
- "What's the total reserve exposure for open deals?"

Click any of the pre-built quick questions in the empty state to get started immediately.

### How It Works

The agent has access to multiple tools:
- **Document Search** — Finds relevant documents by content
- **Portfolio Analytics** — Queries structured data via Cortex Analyst

While the agent is working, you'll see animated status messages indicating which tool it's using (e.g., "Searching documents..." or "Analyzing data...").

### Reading Responses

- Responses render as formatted Markdown including tables and lists
- **Tool indicators** show which tool was used (e.g., "via Search" or "via Analytics")
- **Charts** may be rendered inline when the agent returns data visualizations

### Citations

Document references appear as clickable blue chips:
- `[filename.pdf]` — Click to open the document preview
- `[filename.pdf, p.5]` — Click to open the document at a specific page

### Providing Feedback

Each assistant response has thumbs up/down buttons. Use these to rate response quality — this feedback helps improve the system over time.

### Managing Conversations

- Click **New conversation** to clear the chat history and start fresh
- The conversation is maintained per session only

### Deep Linking

You can pre-populate a question using the URL parameter `?q=`. This is how the Overview page's quick questions work.

---

## Portfolio Analytics

**Path:** `/analytics`

Portfolio Analytics provides visual dashboards and a natural language query interface for analyzing your document portfolio.

### KPI Cards

Four summary metrics at the top:
- **Total Documents** — Count of all indexed documents
- **Document Types** — Number of active taxonomy types
- **Investment Sectors** — Specialty lines being tracked
- **Documents by sector** — Active coverage areas with documents

### Charts

Four visualization panels:

1. **Documents by Type** — Horizontal bar chart showing the top 10 document types by volume
2. **Sector** — Donut/pie chart breaking down documents by sector with legend
3. **Documents by Sector** — Vertical bar chart with color per sector
4. **Document Status** — Vertical bar chart with color coding:
   - Cyan = Open
   - Gray = Closed
   - Green = Bound
   - Amber = Quoted
   - Red = Declined
   - Purple = Reserved

### Natural Language Queries

The analytics page includes a powerful natural language query interface powered by Cortex Analyst:

1. Type your question in the input field (e.g., "How many Digital Infrastructure deals are open by month this year?")
2. Click **Analyze**
3. Results display:
   - **Prose answer** — Natural language summary with a copy button
   - **Generated SQL** — Toggle "Show generated SQL" to see the underlying query (with copy button)
   - **Results table** — First 10 rows of data displayed; truncated with total row count if more

This uses a Semantic View to translate your question into accurate SQL against the document portfolio.

---

## Saved Items

**Path:** `/saved`

Saved Items stores your saved searches and bookmarked documents for quick re-access.

### Saved Searches Tab

Displays all searches you've saved from the Document Search page.

Each entry shows:
- Search name
- Query text (truncated)
- Created date

**Actions:**
- **Run** (green play icon) — Re-executes the search with all original filters
- **Copy Link** — Copies a shareable URL to your clipboard
- **Delete** (red trash) — Permanently removes the saved search

### Bookmarks Tab

Displays all documents you've bookmarked from Search or the Document Browser.

Each entry shows:
- Document type
- Insured name
- Personal note (if added)
- Created date
- File path link (opens document preview)

**Actions:**
- **Delete** (trash icon) — Removes the bookmark

---

## Document Detail View

**Path:** `/documents/detail?id=<file_id>`

The Document Detail page provides a comprehensive view of a single document with full metadata, history, and raw text.

### Header

- File name
- Badges: Document Type, sector, Confidence Score, Status
- **Preview** button — Opens the original document in a viewer
- **Archive** button (admin only) — Hides the document from search results
- **Purge** button (admin only) — Permanently deletes the document and source file (requires double confirmation)

### Navigation

Context-aware back navigation:
- "← Back to Review Queue" (if you came from Review)
- "← Back to Search" (if you came from Search)
- "← Back to Documents" (if you came from the Browser)
- Generic back button otherwise

### Attributes Tab

Displays all extracted fields organized by category:

**Editable fields** (click the pencil icon to correct):
- Insured Name
- Carrier
- Document Type
- Policy Number
- Claim Number
- Sector
- Coverage Form
- Status
- Effective Date
- Expiration Date
- Retroactive Date

Fields with pending corrections show a "Pending" badge.

**Read-only fields:**
- Broker
- Per Occurrence Limit
- Aggregate Limit
- Retention/Deductible
- Summary
- Exclusions Noted
- Action Required

### History Tab

Shows the processing version timeline:
- Version number
- Processing status (Complete, Failed, Processing)
- Start and end timestamps
- Number of attempts
- Error details with the failing stage (if applicable)

### Related Tab

Displays documents related to the current one (sharing the same insured or policy number). Each related document links to its own detail page.

### Raw Text Tab

Shows the full extracted text content:

- **Page count** displayed at the top
- **Highlight Values** toggle — When enabled, color-codes extracted values found in the text:
  - Blue = Identifiers (policy #, claim #)
  - Green = Parties (target company, sponsor, co-investors)
  - Orange = Dates (effective, expiration, retroactive)
  - Purple = Monetary (limits, retention)
  - Gray = Classification (document type, sector)
  - Includes a color legend
- **Search within document** link — Opens Document Search scoped to this file
- **Preview Original** button — Opens the source file viewer

---

## Administration

Administration pages are available to users with the DEAL_INTEL_ADMIN role.

### Pipeline Management

**Path:** `/admin/pipeline`

Manages the end-to-end document processing pipeline with six tabs.

#### Overview Tab

- **Health Metrics** — Cards showing Complete, Pending, Processing, and Failed document counts
- **Stale Queue Warning** — Amber banner if queue age exceeds 120 minutes
- **Task Management** — View all Snowflake tasks with their state and schedule
  - **Suspend** — Pause a running task
  - **Resume** — Restart a suspended task

#### Upload Tab

Upload documents directly into the processing pipeline:

1. Drag-and-drop files onto the upload zone, or click to browse
2. Supported formats: PDF, TIFF, DOCX, PPTX, JPEG, PNG, HTML, TXT (max 50MB per file)
3. Click **Upload and Register** to push files to the ingestion stage

#### Stages Tab

Manage ingestion stages (Snowflake stages configured as document sources):

- View all registered stages with Active/Paused status
- **Toggle** individual stages between Active and Paused
- **Remove** a stage from the registry
- **Add New Stage** — Manual entry with stage name, description, and path prefix
- **Discover Available Stages** — Automatically scan the database for unregistered stages and add them

#### Run Pipeline Tab

Manually trigger individual pipeline steps:
1. **Register Files** — Scan stages for new files and add to the ingestion registry
2. **Parse Documents** — Run AI document parsing (OCR/text extraction)
3. **Classify** — Run AI classification on parsed documents
4. **Extract** — Run AI attribute extraction on classified documents

Each step runs independently. Use this for testing or recovering from partial failures.

#### Processing Logs Tab

View recent processing activity:
- Columns: File, Status, Folder, Type, Insured, Error message
- **Filter by status**: Pending, Processing, Complete, Failed, Abandoned
- **Refresh** to see latest entries

#### Reprocess Tab

Re-queue documents for reprocessing:

1. **Search/filter** by filename, status, sector, or document type
2. **Select** individual documents via checkboxes, or use "Select All"
3. **Reprocess Selected** — Queue chosen documents for reprocessing
4. **Reprocess All Filtered** — Bulk reprocess everything matching current filters
5. **Manual entry** — Enter a specific file path to reprocess

---

### Ingestion Registry

**Path:** `/admin/registry`

The central record of all documents the platform has seen, regardless of processing status.

**Table columns:**
| Column | Description |
|--------|-------------|
| File Path | Full stage path (clickable to preview) |
| Format | File type with colored badge |
| Folder | Source folder/stage |
| Status | Pending, Processing, Complete, Failed, or Abandoned |
| Version | Processing version number |
| Attempts | How many times processing was tried |
| First Seen | When the file was first discovered |
| Last Error | Most recent error message (if any) |

**Features:**
- **Filter** by status and filename search
- **Reprocess** button per document (prompts confirmation for non-failed documents)
- **Pagination** — 50 per page with Previous/Next
- **Refresh** button

---

### Quality & Feedback

**Path:** `/admin/quality`

Monitor extraction quality and manage user-submitted corrections.

#### KPI Cards

- **Average Confidence** — Mean AI confidence score across all documents
- **Low Confidence Count** — Documents below the confidence threshold
- **Low Conf %** — Percentage of documents with low confidence
- **Document Types** — Count of active document types

#### Charts

- **Corrections by Field** — Bar chart showing total corrections vs. approved corrections per field name
- **Average Confidence by sector** — Bar chart with confidence scores and document counts per Sector

#### Pending Corrections Table

Displays corrections submitted by users that need admin review:
- File name (clickable to preview)
- Field corrected
- Original value
- Corrected value
- Submitted by (username)
- Date

**Actions:**
- **Approve** — Accept the correction and update the document
- **Reject** — Dismiss the correction

#### Recent User Feedback Table

Shows thumbs up/down feedback submitted from Search and Chat:
- Feedback type (positive/negative icon)
- File name
- Query text that triggered the feedback
- User
- Date

---

### Cost Dashboard

**Path:** `/admin/cost`

Track Snowflake credit usage attributed to the DealIntel platform.

#### KPI Cards

- **Total Credits (30 days)** — Credits consumed in the last 30 days
- **Daily Average** — Average daily credit consumption
- **Projected Monthly** — Extrapolated monthly cost at current rate

#### Charts

- **Daily Credit Usage** — Line chart spanning 1 year showing daily credit consumption
- **Credits by Stage** — Horizontal bar chart showing which pipeline stages consume the most credits
- **Credits by Event Type** — Vertical bar chart breaking down costs by operation type

#### Cost Optimization Tips

Best practice recommendations for reducing credit usage.

---

### Extraction Schema & Test Lab

**Path:** `/admin/extraction-schema`

Configure what data the AI extracts from documents and test the extraction pipeline.

#### Schema Configuration Tab

The extraction schema uses a three-tier hierarchy:

1. **Common** — Attributes extracted from ALL documents regardless of type
2. **Category** — Attributes extracted only when a document matches a specific classification category
3. **sector-Specific** — Attributes extracted when a document matches both a category AND a Sector

**Navigating the schema:**
- Use the sidebar to browse tiers and groups
- Each group shows its "Fires When" match rule (for Category and sector tiers)
- The attributes table shows: Name, Description, Data Type

**Managing attributes:**
- **Add Attribute** — Create a new extraction field:
  - Select tier (Common, Category, or sector)
  - Choose or create a group
  - Set match rules (which document types/sectors trigger extraction)
  - Define field name, description, and type (VARCHAR, DATE, NUMBER, VARIANT)
- **Delete** — Remove an attribute from the schema
- **Test** (flask icon) — Test a single attribute against a pinned file to verify extraction works

#### Test Lab Tab

The Test Lab lets you run the complete pipeline on sample files without affecting production data.

**File Selection:**
1. Select a Snowflake stage from the dropdown
2. Browse available files (search by name, filter by sector/type)
3. **Pin** individual files or **Pin All Filtered** to add to your test set
4. Pinned files persist in your browser (localStorage)

**Running Tests:**
1. Click **Run Pipeline** to execute: Parse → Classify → Detect sector → Resolve Schema → Extract
2. Results display per file:
   - Classification result
   - sector detection
   - All extracted fields with tier labels
   - Check icon (✓) for successfully extracted values
   - X icon (✗) for empty/missing values
   - Fields are sorted with found values first

**Upload:**
Use the **Upload File** button to add test documents directly to a stage.

Results are NOT saved to the production pipeline — the Test Lab is purely for validation.

---

### Classification Labels

**Path:** `/admin/classification-labels`

Manage the document type taxonomy used by the AI classifier.

**Viewing Labels:**
- Labels are organized by category (e.g., Deal Sourcing, Policy, Deals, Certificates)
- Each label shows its active/disabled status

**Managing Labels:**
- **Add Label** — Enter a label name and select/create a category
- **Create Category** — Add a new grouping category
- **Rename Category** — Edit a category name
- **Delete Category** — Removes the category and all its labels
- **Toggle Active/Disabled** — Disabled labels are excluded from AI classification
- **Delete Label** — Remove an individual label

---

### Investment Sectors

**Path:** `/admin/lobs`

Manage the Investment Sectors (sectors) that documents are assigned to.

**Table columns:** Code, Name, Description, Active status

**Actions:**
- **Add sector** — Enter a unique code, display name, and description
- **Edit** — Modify the name or description inline
- **Toggle Active/Disabled** — Disabled sectors aren't used in classification
- **Delete** — Remove a sector (with confirmation dialog)

---

### Notifications

**Path:** `/admin/notifications`

Configure automated notifications for pipeline events.

**Viewing Rules:**
- Table shows channel type, endpoint, subscribed event types, and active status

**Adding a Rule:**
1. Choose channel: **Webhook** (HTTP POST to a URL) or **Email** (via Snowflake integration)
2. Enter endpoint/address
3. Select event types to subscribe to:
   - INGEST, PARSE, CLASSIFY, EXTRACT
   - ALERT, ARCHIVE, PURGE
   - OVERRIDE, FEEDBACK, DOWNLOAD
4. Set threshold (0 = notify on every event; higher numbers batch)

**Managing Rules:**
- **Toggle** rule active/inactive
- **Delete** a rule permanently

---

### Configuration

**Path:** `/admin/config`

Manage platform-wide settings organized into logical groups.

#### Pipeline Settings

| Setting | Description |
|---------|-------------|
| `pipeline_enabled` | Master on/off for automated processing |
| `batch_size` | Number of documents processed per task execution |
| `max_retries` | Maximum retry attempts for failed documents |
| `reprocess_after_days` | Auto-reprocess documents after N days |
| `max_processing_attempts` | Hard cap on total processing attempts |
| `pipeline_target_lag_minutes` | Target freshness for dynamic tables |

#### AI Models

| Setting | Description |
|---------|-------------|
| `cortex_model` | Model for document classification |
| `extraction_model` | Model for attribute extraction |
| `agent_model` | Model powering the chat agent |
| `search_embedding_model` | Model for search embeddings (locked) |

Model settings show a dropdown with available Cortex models. Some settings are locked (indicated by a lock icon) and cannot be changed through the UI.

#### Quality & Alerts

| Setting | Description |
|---------|-------------|
| `confidence_threshold` | Minimum confidence before flagging for review |
| `classify_confidence_threshold` | Minimum classification confidence |
| `alert_email` | Email address for system alerts |
| `admin_email` | Administrator contact email |
| `cost_alert_multiplier` | Cost spike threshold (e.g., 2.0 = alert at 2× normal) |
| `error_rate_threshold_pct` | Error rate % that triggers alerts |

Each setting has an individual **Save** button. Changes take effect immediately.

---

### Audit Log

**Path:** `/admin/audit`

Track all user and system actions for compliance and troubleshooting.

**Filters:**
- **Time Range** — 7, 14, 30, or 90 days
- **Event Type** — Filter by specific action type
- **User** — Filter by username

**Summary Cards:**
- Top event types with occurrence count and unique user count

**Events Table:**
- Timestamp
- User who performed the action
- Event type
- Affected file path

**Export:**
Click **Export CSV** to download the filtered event list for external analysis.

---

### User Management

**Path:** `/admin/users`

Manage who can access the platform and what they can see.

#### Users Tab

View and manage user entitlements:

- **Add User** — Select from Snowflake role members not yet registered, or enter manually; assign roles
- **Edit** — Change a user's role assignments
- **Deactivate** — Suspend a user's access without deleting their record
- **Reactivate** — Restore a deactivated user
- **Sync from Roles** — Automatically create entitlements for all Snowflake role members not yet configured

#### Roles Tab

Define application roles that control access:

| Permission | Options |
|------------|---------|
| App Pages | Dashboard, Search, Review Queue, Ask a Question, Analytics, Document Browser, Saved Searches, Help |
| sector Access | All (wildcard) or select specific sector codes |
| Document Types | All (wildcard) or select from grouped categories |
| Downloads | Allow or deny document downloads |

**Actions:**
- **Create Role** — Define a new role with name, description, and permissions
- **Edit** — Modify an existing role's permissions
- **Delete** — Remove a role (reassign users first)

#### Investment Sectors Tab

Manage sectors available for role assignment:
- Add, edit, deactivate, or set a default sector
- Separate from the AI Config sectors page — this controls access entitlements

---

## Help & Tips

**Path:** `/help`

### Quick Tips

- **Search is natural language** — Type questions like "find Digital Infrastructure investments with cyber exclusions" rather than keyword-only queries
- **Follow up in chat** — The Deal Intelligence Agent maintains conversation context. Ask follow-up questions to refine answers.
- **Click citation chips** — Blue chips like `[policy.pdf, p.3]` open the source document at the referenced page
- **Batch actions in Browser** — Use checkboxes to select multiple documents for bulk operations
- **Bookmark from Search** — Click the bookmark icon on any search result to save it for later
- **Correct as you go** — Use the pencil icon in the Document Detail view to submit corrections. These improve the AI over time.
- **Keyboard shortcuts** — Press Enter to submit search queries and chat messages

### Understanding Confidence Scores

Confidence scores represent the AI's certainty in its classification:
- **≥85% (Green)** — High confidence, likely correct
- **70–84% (Amber)** — Moderate confidence, may need review
- **<70% (Red)** — Low confidence, flagged for human review

Documents below the configured threshold automatically appear in the Review Queue.

### Document Processing Pipeline

Documents flow through these stages:
1. **Ingest** — File discovered on a stage and registered
2. **Parse** — AI extracts text content (OCR for images/scans)
3. **Classify** — AI determines document type
4. **Extract** — AI pulls structured attributes based on the schema

If any stage fails, the document is marked as Failed and can be reprocessed from Pipeline Management.

---

## Glossary

| Term | Definition |
|------|------------|
| **sector** | Sector — the deal specialty area (e.g., Digital Infrastructure, Cyber, Energy Transition, Marine) |
| **Document Type** | The classification category assigned by AI (e.g., Policy, Claim IC Presentation, Endorsement, Binder) |
| **Confidence** | The AI's self-reported certainty (0–100%) in its classification |
| **Stage** | A Snowflake stage (cloud storage) where source documents are stored |
| **Ingestion Registry** | The master record of all files discovered by the platform |
| **Extraction Schema** | The configured fields that the AI attempts to extract from each document |
| **Cortex Agent** | Snowflake's AI agent framework powering the chat interface |
| **Cortex Analyst** | Snowflake's natural language to SQL engine powering analytics queries |
| **Cortex Search** | Snowflake's AI-powered vector search for document content |
| **RCR** | Restricted Caller's Rights — SPCS security model where the app runs with limited permissions |
| **Semantic View** | A business-level data model that Cortex Analyst uses to translate questions to SQL |

---

*DealIntel v1.0 — Document Intelligence for Infrastructure Investments*
*Powered by Snowflake Cortex AI*
