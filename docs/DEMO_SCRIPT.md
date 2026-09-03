# DealIntel — Demo Script

> **Duration:** 15-20 minutes
> **Audience:** Technical decision-makers, IT leadership, business stakeholders
> **Prerequisites:** DealIntel deployed and accessible, sample documents loaded

---

## Opening (1 minute)

**Key message:** "DealIntel transforms your unstructured deal documents into structured, searchable, actionable data — entirely within Snowflake, with zero data movement and zero external infrastructure."

### Talking Points

- Specialty deal generates thousands of documents: investments, side letters, denials, submissions, loss runs
- These documents contain critical data locked in unstructured formats
- DealIntel uses Snowflake's Cortex AI to automatically parse, classify, and extract key information
- Everything runs natively in your Snowflake account — your data never leaves

---

## Demo Section 1: Overview Dashboard (3 minutes)

**Show:** The Overview page at `/`

### Steps

1. Show the hero banner with all action buttons: Browse, Search, Deal Intelligence, Saved Items, Review Queue
2. Point out the **Portfolio Analytics** section with charts:
   - Documents by Type (horizontal bar chart)
   - Sector breakdown (pie chart)
   - Documents by sector (bar chart)
   - Document Status distribution
3. Use the **"Ask a Question"** panel — type: "How many documents by sector?"
   - Show the agent streaming its response in real-time
   - Point out the result table and auto-generated chart (via ResultChart)
   - Note the "via Analytics" tool badge showing the agent used Cortex Analyst
4. Scroll down to show Quick Questions and Recently Indexed documents

### Talking Point

> "The Overview is your command center. Portfolio analytics, AI-powered Q&A, and quick navigation — all in one place. The Ask a Question panel uses the same Deal Intelligence Agent as the chat page, so you get the full power of Cortex AI right from the home screen."

---

## Demo Section 2: Document Browser (2 minutes)

**Show:** Navigate to Document Browser at `/documents`

### Steps

1. Show the document list with type badges, sector assignments, and status
2. Demonstrate filtering by document type (e.g., "Denial Letter")
3. Filter by Sector (e.g., "Environmental")
4. Click into a document to show the detail view (see Section 3)

### Talking Point

> "Every document is automatically classified into one of 40+ infrastructure PE document types, assigned to a sector, and has key fields extracted — target companies, deal stages, enterprise values, IRR targets, sector classifications. No manual data entry required."

---

## Demo Section 3: Document Detail — Side-by-Side View (3 minutes)

**Show:** Click any document to navigate to the detail page at `/documents/detail`

### Steps

1. Show the **Document tab** — the combined view with:
   - **Left panel:** Rendered PDF with search-within-document capability
   - **Right panel:** All extracted attributes (editable fields + read-only fields)
2. Type a search term in the search bar (e.g., "exclusion") — show matches highlighted in the PDF
3. Use the match navigator to jump between found passages
4. On the right side, demonstrate editing an attribute:
   - Click the pencil icon on "Insured Name"
   - Change the value and submit — show "Correction submitted" toast
   - Note the "Pending" badge on the field
5. Click the **Save** button — show the document is now bookmarked
6. Switch to the **History** tab to show processing version timeline
7. Switch to the **Raw Text** tab with highlight toggle to see extracted values color-coded in context

### Talking Point

> "The document detail gives you everything in one view — the rendered document on the left, all AI-extracted attributes on the right. Search within the document to find specific passages, and correct any extraction errors inline. Every correction is tracked for compliance."

---

## Demo Section 4: AI Search (2 minutes)

**Show:** Navigate to Document Search at `/search`

### Steps

1. Type a semantic query: "cyber liability denial letters from 2024"
2. Show results ranked by relevance with sortable columns
3. Hover over a result to see the preview panel
4. Click a result to navigate to the full detail view
5. Try a specific query: "what investments have aggregate limits over 5 million?"

### Talking Point

> "This is semantic search powered by Cortex Search. It understands the meaning of your query — not just keyword matching. Ask in plain English and find exactly what you need across your entire document portfolio in seconds."

---

## Demo Section 5: AI Q&A — Deal Intelligence (3 minutes)

**Show:** Navigate to Deal Intelligence at `/chat`

### Steps

1. Ask: "What are the most common reasons for claim denials in our environmental liability book?"
2. Show the AI response streaming in with citations to specific documents
3. Click a document filename in the response — show it opens the document preview
4. Ask: "Summarize the key key risks in our Digital Infrastructure investments"
5. Ask an analytics question: "How many documents were processed last month by sector?"
6. Show the response includes a chart generated via the Semantic View

### Talking Point

> "The AI agent combines document search with analytics. It can retrieve specific documents AND query your structured data. It's like having an analyst who has read every document in your system."

---

## Demo Section 6: Saved Items (1 minute)

**Show:** Navigate to Saved Items at `/saved`

### Steps

1. Show the Bookmarks tab — documents you saved from the detail page
2. Click a bookmarked document — navigates directly to the detail view
3. Show the Saved Searches tab — queries you've saved for re-use
4. Click "Run" on a saved search — opens the search page with that query

### Talking Point

> "Save documents you're working with and search queries you run frequently. It's your personal workspace within the document portfolio."

---

## Demo Section 7: Review Queue (2 minutes)

**Show:** Navigate to Review Queue at `/review`

### Steps

1. Show documents flagged for review (low confidence classifications or extractions)
2. Open one — show the AI's extraction alongside the original document text
3. Demonstrate making a correction (override a field value)
4. Show that corrections are tracked in the audit log

### Talking Point

> "AI isn't perfect, and in deal you need accuracy. The review queue surfaces anything the AI is uncertain about. Human corrections feed back into quality metrics, and every change is audit-logged for compliance."

---

## Demo Section 8: Admin — Test Lab (3 minutes)

**Show:** Navigate to Admin > Extraction Schema > Test Lab tab

### Steps

1. Select a stage and pick a sample document
2. Click "Run Pipeline" — show the full pipeline executing in real-time:
   - Parse (document text extracted)
   - Classify (document type identified)
   - Detect sector (sector assigned)
   - Extract (all configured fields extracted)
3. Show the results table with check/X icons for found vs. not-found fields
4. Highlight the tier badges (Common, Category-specific, sector-specific fields)

### Talking Point

> "The Test Lab lets administrators test pipeline changes on real documents before deploying to production. You can add a new extraction field, test it immediately, and see exactly what the AI extracts. No code changes, no redeployment."

---

## Demo Section 9: Admin — Configuration (2 minutes)

**Show:** Quick tour of admin pages

### Steps

1. **Classification Labels** — Show the list of 40+ document types, add/edit/disable
2. **Investment Sectors** — Show configured sectors, toggle active/inactive
3. **Extraction Schema** — Show tiered field configuration:
   - COMMON fields (extracted from all documents)
   - CATEGORY fields (only for specific document types)
   - sector-SPECIFIC fields (only for specific sector + type combinations)

### Talking Point

> "Everything is configurable without code. Add a new document type, configure new extraction fields, change the sector taxonomy — all through the admin UI. Changes take effect immediately for new documents."

---

## Closing — Key Differentiators (1 minute)

### Summary Slide Points

1. **100% Snowflake-native** — Zero external infrastructure. Your data never leaves Snowflake.
2. **AI-powered pipeline** — Parse, classify, and extract with Cortex AI functions.
3. **Configurable without code** — Admin UI for schemas, labels, sectors. No deployments needed.
4. **Semantic search** — Find by meaning, not just keywords.
5. **Integrated document viewer** — See the PDF and extracted data side by side.
6. **Human-in-the-loop** — Review queue ensures accuracy where it matters.
7. **Test before deploy** — Test Lab validates changes on real documents.
8. **Enterprise-grade** — RBAC, audit logging, entitlement-based access control.
9. **Deploy in minutes** — One script provisions everything in any Snowflake account.

### Call to Action

> "DealIntel is ready to deploy in your account today. The provisioning script takes 5 minutes, sample documents are included, and you can be searching your own documents within the hour."

---

## Demo Environment Checklist

- [ ] DealIntel deployed and accessible via HTTPS endpoint
- [ ] Sample documents loaded (IC presentations, DD reports, term sheets, LP reports, etc.)
- [ ] Pipeline has been run (documents parsed, classified, extracted)
- [ ] At least one document bookmarked (to show in Saved Items)
- [ ] At least one document flagged in review queue
- [ ] Test Lab has a stage with documents available
- [ ] User logged in with Administrator role (full feature access)
