#!/usr/bin/env python3
"""
Generate realistic infrastructure PE deal PDF documents for testing the DEAL_INTEL pipeline.
Creates 40+ multi-page PDFs across 8 sectors and 10+ document types.
"""
import os
import random
from datetime import date, timedelta
from fpdf import FPDF

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "generated_docs")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# --- Data pools ---
SECTORS = {
    "DINFRA": "Digital Infrastructure",
    "TRANS": "Transportation & Logistics",
    "ENERGY": "Energy Transition",
    "WATER": "Water & Environmental",
    "SOCIAL": "Social Infrastructure",
    "COMM": "Communications",
    "POWER": "Conventional Power",
    "MULTI": "Multi-Sector Platform",
}

TARGET_COMPANIES = [
    ("Hyperscale Data Centers, LLC", "Owner-operator of hyperscale and enterprise colocation data centers across North America", "DINFRA"),
    ("FiberLink Networks Inc.", "Fiber-to-the-premises network serving metro and rural markets", "DINFRA"),
    ("CloudEdge Partners", "Edge computing platform with 45 micro data centers", "DINFRA"),
    ("TransPeak Logistics, LLC", "Intermodal logistics platform with port, rail, and trucking operations", "TRANS"),
    ("Gateway Logistics Holdings", "Last-mile delivery and warehousing in top 20 MSAs", "TRANS"),
    ("Pacific Maritime Terminal Co.", "Deep-water container terminal on the West Coast", "TRANS"),
    ("Solaris Energy Partners, LLC", "Utility-scale solar and battery storage platform (2.1 GW operating)", "ENERGY"),
    ("WindForce Generation Inc.", "Onshore and offshore wind portfolio (1.4 GW)", "ENERGY"),
    ("GridStore Systems", "Standalone battery energy storage (600 MWh)", "ENERGY"),
    ("ClearWater Utilities", "Municipal water and wastewater concessions in Southeast US", "WATER"),
    ("AquaPure Environmental", "Industrial water treatment and environmental remediation services", "WATER"),
    ("HealthPark Facilities LLC", "Acute care and ambulatory surgical center platform", "SOCIAL"),
    ("Meridian Campus Partners", "University student housing and mixed-use campus facilities", "SOCIAL"),
    ("NorthStar Tower Holdings", "Wireless tower and small cell infrastructure (12,000 sites)", "COMM"),
    ("BroadReach Wireless", "Rural broadband and fixed wireless ISP platform", "COMM"),
    ("Atlas Gas Generation", "Combined cycle natural gas generation fleet (3.2 GW)", "POWER"),
    ("PipelineOne Midstream", "Natural gas gathering and processing in Permian Basin", "POWER"),
    ("Cornerstone Infrastructure", "Diversified infrastructure holding company (3 platform assets)", "MULTI"),
]

FUND_NAMES = [
    "DealIntelligence Infrastructure Fund III",
    "DealIntelligence Infrastructure Fund IV",
    "DealIntelligence Infrastructure Fund V",
    "DealIntelligence Global Renewables Fund I",
    "DealIntelligence Digital Infrastructure Fund",
    "DealIntelligence Credit Fund II",
]

CO_INVESTORS = [
    "GIC", "ADIA", "CPP Investments", "Ontario Teachers'",
    "CalPERS", "CDPQ", "APG", "PSP Investments",
    "Mubadala", "KKR Infrastructure", "Brookfield",
]

DEAL_TEAM = [
    "michael.chen@dealintelligence.com", "sarah.williams@dealintelligence.com",
    "james.park@dealintelligence.com", "lisa.martinez@dealintelligence.com",
    "david.kumar@dealintelligence.com", "rachel.thompson@dealintelligence.com",
    "alex.rodriguez@dealintelligence.com", "emily.wright@dealintelligence.com",
]

ADVISORS = [
    ("Latham & Watkins LLP", "Legal Counsel"),
    ("Kirkland & Ellis LLP", "Legal Counsel"),
    ("Simpson Thacher & Bartlett", "Legal Counsel"),
    ("Goldman Sachs", "Financial Advisor"),
    ("Morgan Stanley Infrastructure", "Financial Advisor"),
    ("Evercore", "Financial Advisor"),
    ("McKinsey & Company", "Commercial Advisor"),
    ("BCG", "Commercial Advisor"),
    ("Black & Veatch", "Technical Advisor"),
    ("Wood Mackenzie", "Market Advisor"),
    ("Marsh", "Insurance Advisor"),
    ("KPMG", "Tax/Accounting Advisor"),
    ("Deloitte", "Tax/Accounting Advisor"),
    ("Ernst & Young", "Financial DD Provider"),
]

GEOGRAPHIES = [
    "United States", "United States (Southeast)", "United States (West Coast)",
    "United States (Texas/ERCOT)", "United States (Northeast)",
    "North America", "Canada", "Australia", "United Kingdom",
]


def random_date(start_year=2022, end_year=2025):
    start = date(start_year, 1, 1)
    end = date(end_year, 12, 31)
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def fmt_money(amount):
    if amount >= 1_000_000_000:
        return f"${amount/1_000_000_000:.1f} billion"
    elif amount >= 1_000_000:
        return f"${amount/1_000_000:.0f} million"
    elif amount >= 1_000:
        return f"${amount:,.0f}"
    return f"${amount}"


# --- Document content generators ---

def gen_ic_presentation(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    ev = random.choice([400_000_000, 800_000_000, 1_500_000_000, 2_800_000_000, 4_200_000_000])
    equity = int(ev * random.uniform(0.4, 0.6))
    debt = ev - equity
    irr = f"{random.randint(15, 25)}-{random.randint(25, 30)}%"
    moic = f"{random.uniform(1.8, 2.8):.1f}-{random.uniform(2.8, 3.5):.1f}x"
    hold = random.choice([3, 4, 5, 6])
    coinvestors = ", ".join(random.sample(CO_INVESTORS, random.randint(1, 3)))

    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "INVESTMENT COMMITTEE PRESENTATION", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, f"Project {deal_code.split('-')[0]} -- {company}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"{fund}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Date: {random_date(2023, 2025)}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "EXECUTIVE SUMMARY", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""DealIntelligence proposes to acquire a 100% interest in {company}, {desc.lower()}.

Target Company: {company}
Sector: {sector_name}
Geography: {geography}
Deal Stage: IC Review
Fund: {fund}

TRANSACTION SUMMARY
Enterprise Value: {fmt_money(ev)}
Equity Check: {fmt_money(equity)}
Net Debt: {fmt_money(debt)} (LTV ~{int(debt/ev*100)}%)
Source of Funds: Fund equity + co-invest
Co-Investors: {coinvestors}

RETURN PROFILE
Target Gross IRR: {irr}
Target Gross MOIC: {moic}
Expected Hold Period: {hold}-{hold+1} years
Exit Path: {random.choice(['Strategic sale', 'IPO', 'Secondary sale', 'Recapitalization'])}""")

    pdf.add_page()
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "INVESTMENT THESIS", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    theses = {
        "DINFRA": ["Secular demand tailwind from AI/ML workloads", "Contracted revenue base with investment-grade counterparties", "Significant organic growth pipeline", "Platform for consolidation of smaller operators"],
        "TRANS": ["Critical infrastructure with high barriers to entry", "Contracted volume base with take-or-pay structures", "Operational improvement opportunity (fleet optimization, automation)", "Geographic expansion through tuck-in acquisitions"],
        "ENERGY": ["Favorable policy tailwinds (IRA/ITC/PTC)", "Long-term contracted cash flows via PPAs", "Development pipeline provides embedded upside", "Declining technology costs improve unit economics"],
        "WATER": ["Essential service with inelastic demand", "Regulated or long-term concession revenue base", "Significant capital investment needs create growth runway", "Fragmented market with consolidation opportunity"],
        "COMM": ["5G/densification driving tower demand", "Long-term lease contracts with annual escalators", "Low churn and high recurring revenue", "Co-location economics drive incremental margin"],
        "POWER": ["Baseload capacity essential for grid reliability", "Favorable spark spread environment", "Capacity market revenues provide downside protection", "Potential for hydrogen/CCUS retrofit"],
    }
    points = theses.get(sector_code, theses["DINFRA"])
    for i, p in enumerate(points, 1):
        pdf.cell(0, 7, f"  {i}. {p}", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "KEY RISKS", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    risks = [
        f"Regulatory/permitting risk in {geography}",
        "Construction cost inflation on growth capex",
        f"Customer concentration (top 3 = {random.randint(40, 70)}% of revenue)",
        "Interest rate environment impact on exit multiple",
        "Integration risk on platform acquisitions",
    ]
    for i, r in enumerate(random.sample(risks, 4), 1):
        pdf.cell(0, 7, f"  {i}. {r}", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "ACTION REQUIRED", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 7, f"IC approval to submit binding bid by {random_date(2024, 2025)}", new_x="LMARGIN", new_y="NEXT")


def gen_term_sheet(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    ev = random.choice([300_000_000, 600_000_000, 1_200_000_000, 2_500_000_000])
    equity = int(ev * random.uniform(0.4, 0.55))
    debt = ev - equity
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "NON-BINDING TERM SHEET", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, f"Project {deal_code.split('-')[0]} -- {sector_name}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Date: {random_date(2023, 2025)}

This non-binding term sheet outlines the principal terms for the acquisition of {company} ("Target") by an entity controlled by {fund}.

Target: {company}
Buyer: NewCo (to be formed by {fund})
Sector: {sector_name}
Geography: {geography}
Transaction Type: {random.choice(['Platform Acquisition', 'Add-On Acquisition', 'Growth Equity', 'Recapitalization'])}

PURCHASE PRICE
Enterprise Value: {fmt_money(ev)}
Equity Contribution: {fmt_money(equity)}
Senior Secured Debt: {fmt_money(debt)}
Implied Multiple: {random.uniform(8.0, 14.0):.1f}x LTM Adjusted EBITDA

KEY TERMS
- 100% acquisition of equity interests
- Customary representations and warranties
- ${random.randint(10, 25)}M escrow ({random.choice([18, 24])}-month survival)
- Non-compete: {random.randint(2, 5)} years, {random.choice(['nationwide', 'sector-wide', 'in relevant markets'])}
- Key management rollover: CEO, CFO, COO

CONDITIONS PRECEDENT
- HSR clearance
- {random.choice(['Lender consent', 'Third-party consent', 'Regulatory approval', 'Environmental clearance'])}
- Key customer consent (top {random.randint(3, 5)} accounts)
- Satisfactory completion of confirmatory due diligence

TIMELINE
- Exclusivity: {random.choice([30, 45, 60])} days from execution
- Expected closing: {random.choice(['Q1', 'Q2', 'Q3', 'Q4'])} {random.randint(2024, 2026)}

DOC STATUS: Draft -- pending GP approval""")


def gen_dd_report(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    advisor_name, advisor_type = random.choice(ADVISORS[6:])  # Technical/market advisors
    dd_type = random.choice(["Technical", "Commercial", "Environmental", "Tax", "Insurance"])
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, f"{dd_type.upper()} DUE DILIGENCE REPORT", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"Project {deal_code.split('-')[0]} -- {company}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Prepared for: DealIntelligence Partners", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Prepared by: {advisor_name}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Date: {random_date(2023, 2025)}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "EXECUTIVE SUMMARY", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)

    findings_map = {
        "Technical": f"""{advisor_name} was engaged by DealIntelligence to conduct independent {dd_type.lower()} due diligence on {company}.

KEY FINDINGS:
1. Asset condition is generally good with maintenance backlog within industry norms
2. Equipment performance within {random.randint(95, 102)}% of design specifications
3. Remaining useful life supports investment thesis hold period
4. Capital expenditure assumptions in management model are reasonable (+/- 10%)
5. No material environmental or structural deficiencies identified

RISK FACTORS:
- Deferred maintenance on {random.randint(2, 5)} non-critical systems (est. ${random.randint(2, 15)}M to address)
- Equipment supplier concentration -- recommend diversification strategy
- Permitting timeline for expansion projects carries {random.randint(6, 18)}-month risk""",
        "Commercial": f"""{advisor_name} was engaged by DealIntelligence to assess the commercial position of {company}.

MARKET POSITION:
- Market share: #{random.randint(1, 5)} in target geography
- Revenue CAGR (3-year): {random.randint(8, 22)}%
- Customer retention rate: {random.randint(90, 98)}%
- Addressable market growing at {random.randint(6, 15)}% annually

COMPETITIVE ANALYSIS:
- Strong competitive moat through {random.choice(['scale advantages', 'network effects', 'regulatory barriers', 'contracted revenue base', 'switching costs'])}
- {random.randint(2, 4)} credible competitors, none with superior cost position
- Management projections are {random.choice(['achievable', 'slightly aggressive', 'conservative'])} based on market assumptions

GROWTH OPPORTUNITIES:
- Organic: {random.choice(['capacity expansion', 'geographic extension', 'product line extension', 'pricing optimization'])}
- Inorganic: {random.randint(3, 8)} actionable M&A targets identified in adjacent markets""",
    }

    pdf.multi_cell(0, 6, findings_map.get(dd_type, findings_map["Technical"]))
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "RECOMMENDATION", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Based on our analysis, we recommend PROCEEDING with the investment subject to:
1. Negotiation of appropriate representations regarding identified issues
2. Price adjustment for deferred maintenance items (if applicable)
3. Confirmation of key assumptions during confirmatory diligence period""")


def gen_investment_memo(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    ev = random.choice([500_000_000, 1_000_000_000, 2_000_000_000, 3_500_000_000])
    equity = int(ev * random.uniform(0.4, 0.55))
    ebitda = int(ev / random.uniform(9.0, 14.0))
    revenue = int(ebitda / random.uniform(0.25, 0.45))
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "INVESTMENT MEMORANDUM", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, f"{company}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"Sector: {sector_name} | Geography: {geography}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Fund: {fund}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Deal Team Lead: {assigned_to}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "COMPANY OVERVIEW", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""{company} is {desc.lower()}.

Revenue (LTM): {fmt_money(revenue)}
Adjusted EBITDA (LTM): {fmt_money(ebitda)}
EBITDA Margin: {int(ebitda/revenue*100)}%
Employees: {random.choice([150, 350, 800, 1500, 3000, 5000])}
Founded: {random.randint(1995, 2018)}
Headquarters: {random.choice(['New York, NY', 'Houston, TX', 'Dallas, TX', 'Denver, CO', 'San Francisco, CA', 'Chicago, IL', 'Atlanta, GA'])}""")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "TRANSACTION OVERVIEW", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Enterprise Value: {fmt_money(ev)}
Entry Multiple: {ev/ebitda:.1f}x LTM EBITDA
Equity Check: {fmt_money(equity)}
Leverage: {(ev-equity)/ebitda:.1f}x Net Debt / EBITDA
Sources: {fund} equity, syndicated term loan, revolver""")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "VALUE CREATION PLAN", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    levers = [
        f"Organic growth: {random.randint(8, 20)}% revenue CAGR through capacity expansion",
        f"Margin improvement: {random.randint(200, 600)}bps EBITDA margin expansion via operational efficiency",
        f"M&A: {random.randint(2, 5)} identified add-on targets totaling {fmt_money(random.randint(100, 500)*1_000_000)} incremental EV",
        f"Multiple expansion: Entry at {ev/ebitda:.1f}x vs comparable exits at {ev/ebitda + random.uniform(1.5, 3.0):.1f}x",
        f"Deleveraging: Pay down {fmt_money(int((ev-equity)*random.uniform(0.2, 0.4)))} of debt from free cash flow",
    ]
    for i, l in enumerate(levers, 1):
        pdf.cell(0, 7, f"  {i}. {l}", new_x="LMARGIN", new_y="NEXT")


def gen_board_deck(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    quarter = random.choice(["Q1", "Q2", "Q3", "Q4"])
    year = random.randint(2023, 2025)
    revenue = random.randint(50, 500) * 1_000_000
    ebitda = int(revenue * random.uniform(0.25, 0.50))
    budget_rev = int(revenue * random.uniform(0.95, 1.10))
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "BOARD OF DIRECTORS MEETING", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, f"{company}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"{quarter} {year} Update | {sector_name}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Date: {random_date(year, year)}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "FINANCIAL HIGHLIGHTS", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    variance = revenue / budget_rev - 1
    pdf.multi_cell(0, 6, f"""Revenue ({quarter} {year}): {fmt_money(revenue)} ({'+' if variance >= 0 else ''}{variance*100:.1f}% vs budget)
Adjusted EBITDA: {fmt_money(ebitda)} ({int(ebitda/revenue*100)}% margin)
Budget EBITDA: {fmt_money(int(budget_rev * random.uniform(0.28, 0.45)))}
Capex (YTD): {fmt_money(int(revenue * random.uniform(0.10, 0.30)))}
Net Debt: {fmt_money(int(revenue * random.uniform(2.0, 5.0)))}
Leverage: {random.uniform(3.0, 5.5):.1f}x Net Debt / LTM EBITDA""")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "OPERATIONAL UPDATE", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    ops = {
        "DINFRA": f"Utilization: {random.randint(75, 95)}% | New leases signed: {random.randint(5, 20)}MW | Development pipeline: {random.randint(50, 300)}MW under construction",
        "TRANS": f"Throughput: {random.randint(80, 110)}% of plan | On-time delivery: {random.randint(92, 99)}% | Fleet utilization: {random.randint(80, 95)}%",
        "ENERGY": f"Generation: {random.randint(95, 105)}% of P50 | Availability: {random.uniform(97, 99.5):.1f}% | PPA coverage: {random.randint(70, 95)}%",
        "WATER": f"Volume treated: {random.randint(90, 105)}% of plan | Compliance: 100% | New concessions won: {random.randint(0, 3)}",
        "COMM": f"Sites activated: {random.randint(100, 500)} ({random.randint(90, 115)}% of plan) | Colocation ratio: {random.uniform(1.5, 2.5):.2f}x | Churn: {random.uniform(0.5, 2.0):.1f}%",
    }
    pdf.multi_cell(0, 6, ops.get(sector_code, ops["DINFRA"]))
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "STRATEGIC INITIATIVES", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    initiatives = [
        f"Add-on pipeline: {random.randint(2, 6)} targets under evaluation",
        f"Operational improvement: {random.choice(['ERP implementation on track', 'Procurement savings ahead of plan', 'Headcount optimization complete'])}",
        f"Growth capex: {random.choice(['Permitting on schedule', 'Construction 2 months ahead', 'Land acquisition complete'])}",
    ]
    for i, init in enumerate(initiatives, 1):
        pdf.cell(0, 7, f"  {i}. {init}", new_x="LMARGIN", new_y="NEXT")


def gen_lp_report(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    quarter = random.choice(["Q1", "Q2", "Q3", "Q4"])
    year = random.randint(2023, 2025)
    fund_size = random.choice([6_000_000_000, 9_000_000_000, 14_000_000_000, 18_000_000_000])
    deployed = int(fund_size * random.uniform(0.5, 0.9))
    tvpi = random.uniform(1.2, 1.8)
    dpi = random.uniform(0.1, 0.5)
    net_irr = random.uniform(12, 22)
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, f"{fund}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, f"QUARTERLY REPORT -- {quarter} {year}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "I", 10)
    pdf.cell(0, 7, "Confidential -- For Limited Partners Only", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "FUND OVERVIEW", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Fund: {fund}
Vintage: {random.randint(2018, 2022)}
Fund Size: {fmt_money(fund_size)}
Invested Capital: {fmt_money(deployed)} ({int(deployed/fund_size*100)}% deployed)
Total Value (TVPI): {tvpi:.2f}x
Net IRR (since inception): {net_irr:.1f}%
DPI: {dpi:.2f}x
Remaining Unfunded: {fmt_money(fund_size - deployed)}""")

    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "PORTFOLIO SUMMARY", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    num_portcos = random.randint(4, 8)
    portcos = random.sample(TARGET_COMPANIES, num_portcos)
    for co_name, co_desc, co_sector in portcos:
        moic = random.uniform(1.0, 2.2)
        pdf.cell(0, 6, f"  - {co_name} ({SECTORS[co_sector]}): {moic:.1f}x Gross MOIC", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "CAPITAL ACTIVITY", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    dist = random.randint(50, 300) * 1_000_000
    call = random.randint(100, 500) * 1_000_000
    pdf.multi_cell(0, 6, f"""Distributions ({quarter}): {fmt_money(dist)}
Capital Calls ({quarter}): {fmt_money(call)}
Net Cash Flow: {fmt_money(dist - call)}""")


def gen_capital_call(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    call_amount = random.choice([50_000_000, 100_000_000, 215_000_000, 350_000_000, 500_000_000])
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 10, "CAPITAL CALL NOTICE", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Date: {random_date(2023, 2025)}

To: Limited Partners of {fund}
From: DealIntelligence Partners (General Partner)
Re: Capital Call -- {fmt_money(call_amount)}

Dear Limited Partners,

Pursuant to Section {random.choice(['3.1', '3.2', '4.1'])} of the Limited Partnership Agreement dated {random_date(2018, 2022)}, the General Partner hereby calls capital in the amount of {fmt_money(call_amount)} ({random.uniform(2, 8):.1f}% of each Limited Partner's unfunded commitment).

PURPOSE OF CALL:
- Investment in {company} ({sector_name}): {fmt_money(int(call_amount * random.uniform(0.7, 0.9)))}
- Management fees: {fmt_money(int(call_amount * random.uniform(0.05, 0.15)))}
- Partnership expenses: {fmt_money(int(call_amount * random.uniform(0.01, 0.05)))}

DUE DATE: {random_date(2024, 2025) + timedelta(days=10)}

WIRE INSTRUCTIONS:
Bank: JPMorgan Chase & Co.
ABA: 021000021
Account: {fund}
Reference: Capital Call #{random.randint(10, 50)}

Please remit your pro rata share by the due date above. Late payments are subject to the default provisions of the LPA.

Sincerely,
DealIntelligence Partners
General Partner""")


def gen_valuation_memo(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    ev = random.choice([500_000_000, 1_200_000_000, 2_500_000_000, 4_000_000_000])
    ebitda = int(ev / random.uniform(9.0, 14.0))
    entry_ev = int(ev * random.uniform(0.6, 0.85))
    entry_multiple = entry_ev / ebitda * random.uniform(0.7, 0.9)
    current_multiple = ev / ebitda
    equity_invested = int(entry_ev * random.uniform(0.4, 0.55))
    nav = int(ev * random.uniform(0.45, 0.6))
    moic = nav / equity_invested

    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "QUARTERLY VALUATION MEMORANDUM", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, f"{company}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 7, f"Fund: {fund} | Sector: {sector_name}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Valuation Date: {random_date(2024, 2025)}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "VALUATION SUMMARY", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Current Enterprise Value: {fmt_money(ev)}
LTM EBITDA: {fmt_money(ebitda)}
Current EV/EBITDA Multiple: {current_multiple:.1f}x
Entry EV/EBITDA Multiple: {entry_multiple:.1f}x

Equity Invested: {fmt_money(equity_invested)}
Current NAV (Equity Value): {fmt_money(nav)}
Gross MOIC: {moic:.2f}x
Gross IRR: {random.uniform(12, 28):.1f}%

METHODOLOGY: {random.choice(['Public comparable companies', 'Precedent transactions', 'DCF (WACC-based)', 'Blend of comparable companies and DCF'])}

COMPARABLE TRADING MULTIPLES:
  Median EV/EBITDA: {random.uniform(9, 15):.1f}x
  Applied multiple: {current_multiple:.1f}x ({random.choice(['at median', 'slight premium for growth', 'modest discount for size'])}""")


def gen_regulatory_filing(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    filing_type = random.choice(["HSR Filing", "CFIUS Notice", "State Regulatory Approval", "Environmental Permit"])
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 10, f"{filing_type.upper()}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "", 10)
    content = {
        "HSR Filing": f"""Hart-Scott-Rodino Premerger Notification

Acquiring Person: {fund} (through NewCo)
Acquired Entity: {company}
Transaction Value: {fmt_money(random.randint(300, 4000) * 1_000_000)}
Filing Date: {random_date(2024, 2025)}
Waiting Period Expires: {random_date(2024, 2025) + timedelta(days=30)}

The parties have filed the required Premerger Notification and Report Form pursuant to Section 7A of the Clayton Act and the HSR Act. The initial 30-day waiting period applies.

Status: {random.choice(['Waiting period running', 'Early termination granted', 'Second request issued', 'Cleared'])}""",
        "CFIUS Notice": f"""Committee on Foreign Investment in the United States
Voluntary Notice

Parties: {fund} and {company}
Transaction: Acquisition of 100% equity interest
Sector: {sector_name}
National Security Considerations: {random.choice(['Critical infrastructure designation', 'Proximity to military installation', 'Government contract involvement', 'Telecommunications infrastructure'])}

Filing Date: {random_date(2024, 2025)}
Review Period: 45 days (initial)
Status: {random.choice(['Under review', 'Cleared with no conditions', 'Cleared with mitigation agreement', 'Withdrawn and refiled'])}""",
    }
    pdf.multi_cell(0, 6, content.get(filing_type, content["HSR Filing"]))


def gen_financial_model(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    base_rev = random.randint(100, 800) * 1_000_000
    growth_rate = random.uniform(0.06, 0.18)
    margin = random.uniform(0.28, 0.50)
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "FINANCIAL MODEL SUMMARY", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, f"{company} -- {sector_name}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 7, f"Model Date: {random_date(2024, 2025)}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, f"Prepared by: {assigned_to}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "5-YEAR PROJECTIONS (Base Case)", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Courier", "", 9)
    pdf.cell(0, 5, f"{'Year':<6}{'Revenue':<14}{'EBITDA':<14}{'Margin':<8}{'Capex':<14}{'FCF':<14}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 5, "-" * 70, new_x="LMARGIN", new_y="NEXT")
    for yr in range(1, 6):
        rev = int(base_rev * (1 + growth_rate) ** yr)
        ebitda = int(rev * margin)
        capex = int(rev * random.uniform(0.10, 0.25))
        fcf = ebitda - capex
        pdf.cell(0, 5, f"{'Y'+str(yr):<6}{fmt_money(rev):<14}{fmt_money(ebitda):<14}{int(margin*100)}%{'':4}{fmt_money(capex):<14}{fmt_money(fcf):<14}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "RETURNS ANALYSIS", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Base Case IRR: {random.uniform(16, 24):.1f}% | MOIC: {random.uniform(2.0, 2.8):.2f}x
Upside Case IRR: {random.uniform(22, 32):.1f}% | MOIC: {random.uniform(2.5, 3.5):.2f}x
Downside Case IRR: {random.uniform(8, 14):.1f}% | MOIC: {random.uniform(1.3, 1.7):.2f}x

Key Sensitivities:
- Revenue growth +/- 2%: IRR impact +/- 300bps
- Exit multiple +/- 1.0x: IRR impact +/- 250bps
- Margin +/- 200bps: IRR impact +/- 150bps""")


def gen_esg_report(pdf, sector_code, sector_name, company, desc, deal_code, fund, geography, assigned_to):
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "ESG / SUSTAINABILITY REPORT", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, f"{company}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 7, f"Sector: {sector_name} | Period: FY {random.randint(2023, 2025)}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "ENVIRONMENTAL", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Scope 1 Emissions: {random.randint(5000, 200000)} tCO2e
Scope 2 Emissions: {random.randint(10000, 500000)} tCO2e
Renewable Energy Usage: {random.randint(15, 85)}%
Water Consumption: {random.randint(100, 5000)} megaliters
Waste Diverted from Landfill: {random.randint(40, 90)}%""")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "SOCIAL", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Total Employees: {random.randint(200, 5000)}
Employee Turnover: {random.randint(8, 25)}%
Gender Diversity (management): {random.randint(25, 50)}% female
Lost Time Injury Rate: {random.uniform(0.1, 2.0):.2f}
Community Investment: {fmt_money(random.randint(100, 2000) * 1000)}""")
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "GOVERNANCE", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, f"""Board Independence: {random.randint(50, 80)}%
Board Diversity: {random.randint(25, 50)}% female / underrepresented
Cybersecurity Framework: {random.choice(['NIST CSF', 'ISO 27001', 'SOC 2 Type II'])}
Anti-Corruption Training: {random.randint(90, 100)}% completion""")


# --- Main generator ---
DOC_GENERATORS = {
    "ic_presentation": ("IC Presentation", gen_ic_presentation),
    "term_sheet": ("Term Sheet", gen_term_sheet),
    "dd_report": ("DD Report", gen_dd_report),
    "investment_memo": ("Investment Memo", gen_investment_memo),
    "board_deck": ("Board Deck", gen_board_deck),
    "lp_report": ("LP Report", gen_lp_report),
    "capital_call": ("Capital Call Notice", gen_capital_call),
    "valuation_memo": ("Valuation Memo", gen_valuation_memo),
    "regulatory_filing": ("Regulatory Filing", gen_regulatory_filing),
    "financial_model": ("Financial Model", gen_financial_model),
    "esg_report": ("ESG / Sustainability Report", gen_esg_report),
}

# Define which doc types make sense for which sectors
SECTOR_DOC_TYPES = {
    "DINFRA": ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "capital_call", "valuation_memo", "financial_model", "esg_report"],
    "TRANS":  ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "capital_call", "valuation_memo", "regulatory_filing", "financial_model"],
    "ENERGY": ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "capital_call", "valuation_memo", "regulatory_filing", "financial_model", "esg_report"],
    "WATER":  ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "valuation_memo", "regulatory_filing", "esg_report"],
    "SOCIAL": ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "valuation_memo", "financial_model"],
    "COMM":   ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "capital_call", "valuation_memo", "regulatory_filing", "financial_model"],
    "POWER":  ["ic_presentation", "term_sheet", "dd_report", "investment_memo", "board_deck", "lp_report", "valuation_memo", "regulatory_filing", "financial_model", "esg_report"],
    "MULTI":  ["board_deck", "lp_report", "capital_call", "valuation_memo", "financial_model", "esg_report"],
}


def sanitize_text(text):
    """Replace unicode characters that fpdf can't handle with ASCII equivalents."""
    replacements = {
        '\u2014': '--',
        '\u2013': '-',
        '\u2018': "'",
        '\u2019': "'",
        '\u201c': '"',
        '\u201d': '"',
        '\u2026': '...',
        '\u2022': '*',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class SafePDF(FPDF):
    """FPDF subclass that sanitizes text before rendering."""
    def multi_cell(self, *args, **kwargs):
        if args:
            args = list(args)
            for i, a in enumerate(args):
                if isinstance(a, str):
                    args[i] = sanitize_text(a)
            args = tuple(args)
        if 'text' in kwargs and isinstance(kwargs['text'], str):
            kwargs['text'] = sanitize_text(kwargs['text'])
        if 'txt' in kwargs and isinstance(kwargs['txt'], str):
            kwargs['txt'] = sanitize_text(kwargs['txt'])
        return super().multi_cell(*args, **kwargs)

    def cell(self, *args, **kwargs):
        if args:
            args = list(args)
            for i, a in enumerate(args):
                if isinstance(a, str):
                    args[i] = sanitize_text(a)
            args = tuple(args)
        if 'text' in kwargs and isinstance(kwargs['text'], str):
            kwargs['text'] = sanitize_text(kwargs['text'])
        if 'txt' in kwargs and isinstance(kwargs['txt'], str):
            kwargs['txt'] = sanitize_text(kwargs['txt'])
        return super().cell(*args, **kwargs)


def generate_all(target_count=1000):
    """Generate target_count PDF documents with full variability."""
    random.seed(42)
    doc_count = 0
    manifest = []

    # Build weighted distribution of sector x doc_type combos
    all_combos = []
    for sector_code, sector_name in SECTORS.items():
        for doc_type_key in SECTOR_DOC_TYPES[sector_code]:
            all_combos.append((sector_code, sector_name, doc_type_key))

    while doc_count < target_count:
        sector_code, sector_name, doc_type_key = random.choice(all_combos)
        doc_type_name, gen_func = DOC_GENERATORS[doc_type_key]

        # Pick a company matching the sector, or random if multi
        sector_companies = [(n, d, s) for n, d, s in TARGET_COMPANIES if s == sector_code]
        if not sector_companies:
            sector_companies = TARGET_COMPANIES
        company_name, company_desc, _ = random.choice(sector_companies)

        deal_code = f"{sector_code}-{random.randint(2022, 2026)}-{random.randint(100, 999)}"
        fund = random.choice(FUND_NAMES)
        geography = random.choice(GEOGRAPHIES)
        assigned_to = random.choice(DEAL_TEAM)

        pdf = SafePDF()
        pdf.add_page()
        pdf.set_auto_page_break(auto=True, margin=15)

        gen_func(pdf, sector_code, sector_name, company_name, company_desc,
                 deal_code, fund, geography, assigned_to)

        seq = str(doc_count + 1).zfill(4)
        filename = f"{seq}-{sector_code}-{doc_type_key}-{company_name.split(',')[0].split(' ')[0].lower()}-{deal_code}.pdf"
        filename = filename.replace(" ", "_").replace("/", "-")
        filepath = os.path.join(OUTPUT_DIR, filename)

        pdf.output(filepath)
        doc_count += 1
        manifest.append({
            "filename": filename,
            "sector": sector_name,
            "sector_code": sector_code,
            "doc_type": doc_type_name,
            "company": company_name,
            "deal_code": deal_code,
            "fund": fund,
            "geography": geography,
        })

        if doc_count % 100 == 0:
            print(f"  Generated {doc_count}/{target_count} documents...")

    print(f"\nGenerated {doc_count} PDF documents in {OUTPUT_DIR}")
    print(f"\nBy Sector:")
    from collections import Counter
    sector_counts = Counter(m["sector"] for m in manifest)
    for sector, cnt in sorted(sector_counts.items()):
        print(f"  {sector}: {cnt}")
    print(f"\nBy Document Type:")
    type_counts = Counter(m["doc_type"] for m in manifest)
    for dt, cnt in sorted(type_counts.items()):
        print(f"  {dt}: {cnt}")

    import json
    manifest_path = os.path.join(OUTPUT_DIR, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest written to {manifest_path}")


if __name__ == "__main__":
    import sys
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    generate_all(target_count=count)
