"""Generate the synthetic student-load warehouse as dbt seed CSVs.

Everything here is made up: aggregate counts only, generic faculty/course names,
illustrative funding rates. Deterministic (fixed seed) so rebuilds are identical.

Run:  uv run python scripts/generate_data.py
"""

from __future__ import annotations

import csv
import math
import random
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parent.parent / "seeds"
rng = random.Random(20261102)

ACTUAL_YEARS = list(range(2019, 2026))  # full-year actuals
PLAN_YEAR = 2026
CURRENT_CYCLE_WEEK = 14  # applications for the 2027 intake are at week 14 of 30
CITIZENSHIPS = ["Domestic", "International"]

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
FACULTIES = [
    ("ART", "Arts & Social Sciences"),
    ("BUS", "Business"),
    ("ENG", "Engineering"),
    ("SCI", "Science"),
    ("MED", "Medicine & Health"),
    ("LAW", "Law"),
    ("ADP", "Architecture, Design & Planning"),
    ("MUS", "Music & Performing Arts"),
]

# 2026 illustrative per-EFTSL rates by funding cluster (not official values).
CLUSTERS = [
    ("C1", "Law, business, humanities, creative arts", 1_301, 17_000),
    ("C2", "Education, nursing, IT, psychology", 15_000, 4_700),
    ("C3", "Science, engineering, health, built environment", 18_500, 9_000),
    ("C4", "Medicine, dentistry, veterinary science", 30_000, 13_500),
]

# code, name, faculty, level, cluster, duration, 2025 domestic intake, 2025 intl intake, domestic funding
COURSES = [
    ("ART-BA", "Bachelor of Arts", "ART", "UG", "C1", 3, 1800, 300, "CSP"),
    ("ART-BED", "Bachelor of Education", "ART", "UG", "C2", 4, 450, 40, "CSP"),
    ("ART-MTEACH", "Master of Teaching", "ART", "PGCW", "C2", 2, 250, 60, "CSP"),
    ("ART-MIR", "Master of International Relations", "ART", "PGCW", "C1", 2, 60, 350, "DFEE"),
    ("ART-PHD", "Doctor of Philosophy (Arts)", "ART", "HDR", "C1", 4, 50, 25, "RTP"),
    ("BUS-BCOM", "Bachelor of Commerce", "BUS", "UG", "C1", 3, 1100, 1400, "CSP"),
    ("BUS-MCOM", "Master of Commerce", "BUS", "PGCW", "C1", 2, 150, 2200, "DFEE"),
    ("BUS-MBA", "Master of Business Administration", "BUS", "PGCW", "C1", 2, 120, 180, "DFEE"),
    ("BUS-MPA", "Master of Professional Accounting", "BUS", "PGCW", "C1", 2, 40, 900, "DFEE"),
    ("BUS-PHD", "Doctor of Philosophy (Business)", "BUS", "HDR", "C1", 4, 15, 20, "RTP"),
    ("ENG-BE", "Bachelor of Engineering Honours", "ENG", "UG", "C3", 4, 900, 700, "CSP"),
    ("ENG-BADVC", "Bachelor of Advanced Computing", "ENG", "UG", "C2", 4, 500, 600, "CSP"),
    ("ENG-MPE", "Master of Professional Engineering", "ENG", "PGCW", "C3", 2, 80, 900, "DFEE"),
    ("ENG-MDS", "Master of Data Science", "ENG", "PGCW", "C2", 2, 60, 800, "DFEE"),
    ("ENG-PHD", "Doctor of Philosophy (Engineering)", "ENG", "HDR", "C3", 4, 60, 70, "RTP"),
    ("SCI-BSC", "Bachelor of Science", "SCI", "UG", "C3", 3, 1500, 500, "CSP"),
    ("SCI-BPSYC", "Bachelor of Psychology", "SCI", "UG", "C2", 4, 400, 80, "CSP"),
    ("SCI-BVS", "Bachelor of Veterinary Science", "SCI", "UG", "C4", 5, 120, 40, "CSP"),
    ("SCI-MENV", "Master of Environmental Science", "SCI", "PGCW", "C3", 2, 50, 200, "DFEE"),
    ("SCI-PHD", "Doctor of Philosophy (Science)", "SCI", "HDR", "C3", 4, 90, 60, "RTP"),
    ("MED-MD", "Doctor of Medicine", "MED", "PGCW", "C4", 4, 250, 50, "CSP"),
    ("MED-BN", "Bachelor of Nursing", "MED", "UG", "C2", 3, 400, 150, "CSP"),
    ("MED-BPHARM", "Bachelor of Pharmacy", "MED", "UG", "C3", 4, 200, 120, "CSP"),
    ("MED-MPH", "Master of Public Health", "MED", "PGCW", "C3", 2, 100, 300, "DFEE"),
    ("MED-PHD", "Doctor of Philosophy (Medicine)", "MED", "HDR", "C4", 4, 120, 60, "RTP"),
    ("LAW-LLB", "Bachelor of Laws", "LAW", "UG", "C1", 5, 350, 60, "CSP"),
    ("LAW-JD", "Juris Doctor", "LAW", "PGCW", "C1", 3, 200, 60, "DFEE"),
    ("LAW-LLM", "Master of Laws", "LAW", "PGCW", "C1", 2, 40, 120, "DFEE"),
    ("ADP-BDESARCH", "Bachelor of Design in Architecture", "ADP", "UG", "C3", 3, 250, 150, "CSP"),
    ("ADP-MARCH", "Master of Architecture", "ADP", "PGCW", "C3", 2, 80, 120, "DFEE"),
    ("ADP-MURBPL", "Master of Urban Planning", "ADP", "PGCW", "C3", 2, 40, 100, "DFEE"),
    ("MUS-BMUS", "Bachelor of Music", "MUS", "UG", "C1", 4, 200, 20, "CSP"),
    ("MUS-MMUS", "Master of Music Studies", "MUS", "PGCW", "C1", 2, 20, 30, "DFEE"),
]

# Intake index relative to 2025 (COVID dip for international, domestic surge in 2021).
DOM_INDEX = {2013: 0.88, 2014: 0.89, 2015: 0.90, 2016: 0.91, 2017: 0.92, 2018: 0.93,
             2019: 0.94, 2020: 0.97, 2021: 1.03, 2022: 0.99, 2023: 0.95, 2024: 0.98, 2025: 1.00}
INTL_INDEX = {2013: 0.70, 2014: 0.74, 2015: 0.78, 2016: 0.83, 2017: 0.88, 2018: 0.93,
              2019: 0.97, 2020: 0.62, 2021: 0.55, 2022: 0.80, 2023: 0.98, 2024: 1.05, 2025: 1.00}

BASE_RETENTION = {("UG", "Domestic"): 0.88, ("UG", "International"): 0.91,
                  ("PGCW", "Domestic"): 0.90, ("PGCW", "International"): 0.93,
                  ("HDR", "Domestic"): 0.92, ("HDR", "International"): 0.94}
BASE_LOAD = {("UG", "Domestic"): 0.88, ("UG", "International"): 0.96,
             ("PGCW", "Domestic"): 0.66, ("PGCW", "International"): 0.95,
             ("HDR", "Domestic"): 0.84, ("HDR", "International"): 0.97}
MID_YEAR_SHARE = {"UG": 0.05, "PGCW": 0.20, "HDR": 0.30}

# Equity shares of domestic students (2025 level) by faculty, drifting up ~0.3pp a year.
LOW_SES = {"ART": 0.15, "BUS": 0.10, "ENG": 0.11, "SCI": 0.12, "MED": 0.13, "LAW": 0.07, "ADP": 0.09, "MUS": 0.11}
FIRST_NATIONS_BASE, REGIONAL_BASE = 0.021, 0.155


def fac(course):
    return course[2]


def intl_fee(course, year):
    base = {"UG": 52_000, "PGCW": 54_000, "HDR": 48_000}[course[3]]
    if course[2] == "MED":
        base += 18_000
    if course[2] in ("ART", "MUS"):
        base -= 6_000
    return round(base * 1.04 ** (year - 2026), -2)


def cluster_rate(cluster_code, year):
    _, _, cgs, contrib = next(c for c in CLUSTERS if c[0] == cluster_code)
    return cgs * 1.03 ** (year - 2026), contrib * 1.03 ** (year - 2026)


def revenue_per_eftsl(course, citizenship, year):
    if citizenship == "International":
        return intl_fee(course, year)
    funding = course[8]
    if funding == "CSP":
        cgs, contrib = cluster_rate(course[4], year)
        return round(cgs + contrib)
    if funding == "DFEE":
        return round(34_000 * 1.04 ** (year - 2026), -2)
    return round(41_000 * 1.03 ** (year - 2026), -2)  # RTP block grant per EFTSL (illustrative)


def jitter(x, pct):
    return x * (1 + rng.uniform(-pct, pct))


# ---------------------------------------------------------------------------
# Actual intakes and cohort roll-forward
# ---------------------------------------------------------------------------
intake = {}  # (course, citizenship, year) -> commencing headcount
for c in COURSES:
    for cit in CITIZENSHIPS:
        base = c[6] if cit == "Domestic" else c[7]
        idx = DOM_INDEX if cit == "Domestic" else INTL_INDEX
        for y in range(2013, 2026):
            val = base * idx[y]
            if c[3] == "PGCW" and cit == "International" and y >= 2023:
                val *= 1.0 + 0.03 * (y - 2022)  # slow PGCW intl growth
            intake[(c[0], cit, y)] = max(0, round(jitter(val, 0.04)))


def retention_actual(c, cit, y):
    r = BASE_RETENTION[(c[3], cit)]
    if y in (2021, 2022) and cit == "Domestic":
        r -= 0.02  # post-COVID attrition
    return round(min(0.99, jitter(r, 0.01)), 4)


def load_actual(c, cit, y):
    return round(jitter(BASE_LOAD[(c[3], cit)], 0.015), 4)


def continuing_base(c, cit, y, intakes):
    """Students eligible to continue into year y (before applying retention)."""
    dur = c[5]
    total = 0.0
    for k in range(1, dur):
        surv = BASE_RETENTION[(c[3], cit)] ** (k - 1)
        total += intakes.get((c[0], cit, y - k), 0) * surv
    total += 0.25 * intakes.get((c[0], cit, y - dur), 0) * BASE_RETENTION[(c[3], cit)] ** (dur - 1)
    return round(total)


def equity_shares(c, y):
    drift = 0.003 * (y - 2025)
    low = max(0.02, jitter(LOW_SES[fac(c)] + drift, 0.05))
    fn = max(0.005, jitter(FIRST_NATIONS_BASE + 0.001 * (y - 2025), 0.10))
    reg = max(0.05, jitter(REGIONAL_BASE + 0.002 * (y - 2025), 0.05))
    return round(low, 4), round(fn, 4), round(reg, 4)


assumptions = []  # rows for load_assumptions.csv


def add_assumption(version, y, c, cit, comm, cont_base, ret, load, shares):
    low, fn, reg = shares if cit == "Domestic" else ("", "", "")
    assumptions.append({
        "version_code": version, "plan_year": y, "course_code": c[0], "citizenship": cit,
        "commencing_intake": comm, "continuing_base_hc": cont_base,
        "retention_rate": ret, "load_per_student": load,
        "revenue_per_eftsl": revenue_per_eftsl(c, cit, y),
        "low_ses_share": low, "first_nations_share": fn, "regional_share": reg,
    })


for y in ACTUAL_YEARS:
    for c in COURSES:
        for cit in CITIZENSHIPS:
            add_assumption("ACT", y, c, cit, intake[(c[0], cit, y)], continuing_base(c, cit, y, intake),
                           retention_actual(c, cit, y), load_actual(c, cit, y), equity_shares(c, y))

# ---------------------------------------------------------------------------
# Plan versions
# ---------------------------------------------------------------------------
def plan_rows(version, y, intake_fn, ret_fn, load_fn):
    for c in COURSES:
        for cit in CITIZENSHIPS:
            base_ret = BASE_RETENTION[(c[3], cit)]
            base_load = BASE_LOAD[(c[3], cit)]
            add_assumption(version, y, c, cit, round(intake_fn(c, cit)), continuing_base(c, cit, y, intake),
                           round(ret_fn(c, cit, base_ret), 4), round(load_fn(c, cit, base_load), 4),
                           equity_shares_plan(c, y))


_plan_shares = {}


def equity_shares_plan(c, y):
    if (c[0], y) not in _plan_shares:
        _plan_shares[(c[0], y)] = equity_shares(c, y)
    return _plan_shares[(c[0], y)]


# Budget 2025 (to compare with 2025 actuals): optimistic international growth.
plan_rows("BUD25", 2025,
          lambda c, cit: intake[(c[0], cit, 2024)] * (1.02 if cit == "Domestic" else 1.06),
          lambda c, cit, r: r, lambda c, cit, l: l)

# Budget 2026: growth on 2025 actuals.
bud26 = {(c[0], cit): intake[(c[0], cit, 2025)] * (1.02 if cit == "Domestic" else 1.04)
         for c in COURSES for cit in CITIZENSHIPS}
plan_rows("BUD26", 2026, lambda c, cit: bud26[(c[0], cit)], lambda c, cit, r: r, lambda c, cit, l: l)


def q1f_intake(c, cit):
    v = bud26[(c[0], cit)]
    if cit == "International" and fac(c) == "BUS":
        v *= 0.82  # story: business international shortfall
    if cit == "International" and fac(c) == "ENG":
        v *= 0.88  # story: engineering international shortfall
    if cit == "Domestic" and c[0] == "MED-BN":
        v *= 0.90  # story: shift from UG nursing ...
    if cit == "Domestic" and c[0] == "MED-MPH":
        v *= 1.35  # ... toward postgraduate public health
    if cit == "Domestic" and fac(c) == "SCI" and c[3] == "UG":
        v *= 1.06  # story: domestic science demand up (pushes C3 over cap)
    return v


def q1f_ret(c, cit, r):
    return r - 0.03 if fac(c) == "ART" else r  # story: arts retention dip


def q1f_load(c, cit, l):
    return l - 0.03 if fac(c) == "ENG" else l  # story: more part-time study in engineering


plan_rows("Q1F26", 2026, q1f_intake, q1f_ret, q1f_load)


def q2f_intake(c, cit):
    v = q1f_intake(c, cit)
    if cit == "International" and fac(c) == "BUS":
        v *= 0.88 / 0.82  # mid-year intake partly recovers business
    if cit == "Domestic" and fac(c) == "SCI" and c[3] == "UG":
        v *= 1.07 / 1.06
    return v


plan_rows("Q2F26", 2026, q2f_intake, q1f_ret, q1f_load)

# 2026 "actual" intake (for S1 census and application curves) tracks Q2F with noise.
for c in COURSES:
    for cit in CITIZENSHIPS:
        intake[(c[0], cit, 2026)] = round(jitter(q2f_intake(c, cit), 0.02))

# ---------------------------------------------------------------------------
# Term-level actuals (2019–2025 both semesters, 2026 S1 only)
# ---------------------------------------------------------------------------
term_rows = []
assump_by_key = {(a["version_code"], a["plan_year"], a["course_code"], a["citizenship"]): a for a in assumptions}
for y in ACTUAL_YEARS + [2026]:
    for c in COURSES:
        for cit in CITIZENSHIPS:
            if y == 2026:
                a = dict(assump_by_key[("Q2F26", 2026, c[0], cit)])
                a["commencing_intake"] = intake[(c[0], cit, 2026)]
            else:
                a = assump_by_key[("ACT", y, c[0], cit)]
            comm = a["commencing_intake"]
            cont = a["continuing_base_hc"] * a["retention_rate"]
            load = a["load_per_student"]
            mid = MID_YEAR_SHARE[c[3]]
            shares = (a["low_ses_share"], a["first_nations_share"], a["regional_share"])
            for status, hc_year in (("Commencing", comm), ("Continuing", cont)):
                eftsl_year = hc_year * load
                hc_s1 = hc_year * (1 - mid) if status == "Commencing" else hc_year
                eftsl_s1 = hc_s1 * load * 0.5
                terms = [("S1", hc_s1, eftsl_s1)]
                if y < 2026:
                    # "Commencing" means first year of course, so S2 holds S1 commencers who stayed
                    # plus the mid-year intake; continuing headcount thins slightly by S2.
                    if status == "Commencing":
                        hc_s2 = hc_year * (1 - mid) * 0.95 + hc_year * mid
                    else:
                        hc_s2 = hc_year * 0.97
                    terms.append(("S2", hc_s2, eftsl_year - eftsl_s1))
                for term, hc, eftsl in terms:
                    hc = round(hc)
                    row = {"census_year": y, "term": term, "course_code": c[0], "citizenship": cit,
                           "commencement_status": status, "headcount": hc, "eftsl": round(eftsl, 2)}
                    if cit == "Domestic":
                        row.update(hc_low_ses=round(hc * shares[0]), hc_first_nations=round(hc * shares[1]),
                                   hc_regional=round(hc * shares[2]))
                    else:
                        row.update(hc_low_ses=0, hc_first_nations=0, hc_regional=0)
                    term_rows.append(row)

# ---------------------------------------------------------------------------
# Applications pipeline for domestic CSP undergraduate courses (intake 2019–2027)
# ---------------------------------------------------------------------------
def logistic(w, mid, k):
    return 1 / (1 + math.exp(-k * (w - mid)))


app_rows = []
for c in COURSES:
    if not (c[3] == "UG" and c[8] == "CSP"):
        continue
    for iy in range(2019, 2028):
        if iy <= 2026:
            census = intake[(c[0], "Domestic", iy)] * (1 - MID_YEAR_SHARE["UG"])
        else:
            census = intake[(c[0], "Domestic", 2026)] * (1 - MID_YEAR_SHARE["UG"]) * 1.04  # 2027 tracking up ~4%
        melt = rng.uniform(0.90, 0.95)
        accepts = census / melt
        offers = accepts / rng.uniform(0.52, 0.60)
        apps = offers / rng.uniform(0.66, 0.74)
        shift = rng.uniform(-1.2, 1.2)  # cycle timing varies a little by year
        last_week = CURRENT_CYCLE_WEEK if iy == 2027 else 30
        for w in range(1, last_week + 1):
            app_rows.append({
                "intake_year": iy, "week_of_cycle": w, "course_code": c[0],
                "applications_cum": round(apps * logistic(w, 11 + shift, 0.38)),
                "offers_cum": round(offers * logistic(w, 21 + shift, 0.55)),
                "acceptances_cum": round(accepts * logistic(w, 23.5 + shift, 0.6)),
            })

# ---------------------------------------------------------------------------
# Caps and targets (2026)
# ---------------------------------------------------------------------------
def bud26_csp_eftsl(cluster):
    total = 0.0
    for a in assumptions:
        if a["version_code"] != "BUD26" or a["citizenship"] != "Domestic":
            continue
        c = next(x for x in COURSES if x[0] == a["course_code"])
        if c[4] == cluster and c[8] == "CSP":
            total += (a["commencing_intake"] + a["continuing_base_hc"] * a["retention_rate"]) * a["load_per_student"]
    return total


cap_factor = {"C1": 1.04, "C2": 1.03, "C3": 0.985, "C4": 1.006}
caps = []
for code, name, *_ in CLUSTERS:
    caps.append({"plan_year": 2026, "cap_code": f"CSP-{code}", "cap_type": "CSP funding envelope",
                 "scope_type": "funding_cluster", "scope_code": code, "measure": "CSP EFTSL",
                 "direction": "max", "target_value": round(bud26_csp_eftsl(code) * cap_factor[code], -1),
                 "description": f"Managed growth target for cluster {code} ({name}); CGS is not paid above it"})
bud_intl = sum(a["commencing_intake"] for a in assumptions
               if a["version_code"] == "BUD26" and a["citizenship"] == "International")
caps += [
    {"plan_year": 2026, "cap_code": "INTL-COMM", "cap_type": "International planning level",
     "scope_type": "university", "scope_code": "ALL", "measure": "International commencements",
     "direction": "max", "target_value": round(bud_intl * 0.955, -2),
     "description": "Government-set cap on new overseas student commencements"},
    {"plan_year": 2026, "cap_code": "EQ-LOWSES", "cap_type": "Equity target", "scope_type": "university",
     "scope_code": "ALL", "measure": "Low SES share of domestic UG commencements", "direction": "min",
     "target_value": 0.15, "description": "Strategic target for low socio-economic status access"},
    {"plan_year": 2026, "cap_code": "EQ-FIRSTNATIONS", "cap_type": "Equity target", "scope_type": "university",
     "scope_code": "ALL", "measure": "First Nations share of domestic UG commencements", "direction": "min",
     "target_value": 0.03, "description": "Strategic target for First Nations participation"},
    {"plan_year": 2026, "cap_code": "EQ-REGIONAL", "cap_type": "Equity target", "scope_type": "university",
     "scope_code": "ALL", "measure": "Regional and remote share of domestic UG commencements", "direction": "min",
     "target_value": 0.18, "description": "Strategic target for regional and remote access"},
]

# ---------------------------------------------------------------------------
# Write seeds
# ---------------------------------------------------------------------------
def write(name, rows, fields=None):
    SEED_DIR.mkdir(exist_ok=True)
    fields = fields or list(rows[0].keys())
    with open(SEED_DIR / f"{name}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"{name}.csv: {len(rows)} rows")


write("faculties", [{"faculty_code": k, "faculty_name": v} for k, v in FACULTIES])
write("courses", [{"course_code": c[0], "course_name": c[1], "faculty_code": c[2], "course_level": c[3],
                   "funding_cluster": c[4], "duration_years": c[5], "domestic_funding_type": c[8]}
                  for c in COURSES])
write("funding_rates", [{"plan_year": y, "cluster_code": code, "cluster_name": name,
                         "cgs_per_eftsl": round(cluster_rate(code, y)[0]),
                         "student_contribution_per_eftsl": round(cluster_rate(code, y)[1])}
                        for y in range(2019, 2027) for code, name, *_ in CLUSTERS])
write("plan_versions", [
    {"version_code": "ACT", "version_name": "Actuals", "version_type": "Actual", "plan_year": "", "published_on": "", "sort_order": 0},
    {"version_code": "BUD25", "version_name": "Budget 2025", "version_type": "Budget", "plan_year": 2025, "published_on": "2024-11-29", "sort_order": 1},
    {"version_code": "BUD26", "version_name": "Budget 2026", "version_type": "Budget", "plan_year": 2026, "published_on": "2025-11-28", "sort_order": 2},
    {"version_code": "Q1F26", "version_name": "Q1 Forecast 2026", "version_type": "Forecast", "plan_year": 2026, "published_on": "2026-04-17", "sort_order": 3},
    {"version_code": "Q2F26", "version_name": "Q2 Forecast 2026", "version_type": "Forecast", "plan_year": 2026, "published_on": "2026-07-24", "sort_order": 4},
])
write("load_assumptions", assumptions)
write("load_actuals_term", term_rows)
write("applications_weekly", app_rows)
write("caps_targets", caps)
