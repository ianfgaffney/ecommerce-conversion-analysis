# E-commerce Conversion Analysis

**BigQuery SQL · Python · Tableau**

An analysis of recorded shopping progression in Google Merchandise Store sample data, combining session modeling, statistical uncertainty, measurement diagnostics, and experiment planning.

**[Explore the interactive Tableau dashboard](https://public.tableau.com/app/profile/ian.gaffney/viz/E-CommerceConversionOptimization/ExecutiveOverview)**

## Business question

Where does recorded shopping progression stop, is there evidence of a device-specific conversion problem, and what checkout improvement would be worth testing?

## Main findings

- **Overall:** 4,848 of 360,129 sessions contained a purchase, a session purchase rate of **1.35%**.
- **Device comparison:** The observed mobile-minus-desktop difference was **+0.0776 percentage points**. Its user-bootstrap 95% interval, **−0.0051 to +0.1610 percentage points**, includes zero. The analysis does not establish a clear population-level device advantage.
- **Measurement:** The raw-event audit found no mobile/desktop cart events on **November 2–15 and November 21–24, 2020**, despite recorded checkout and purchase activity. The cause is unknown.
- **Restricted funnel:** December–January mobile/desktop sessions provide a narrower analysis of strictly ordered, same-session progression. Of **4,246** ordered checkout sessions, **2,301** recorded a subsequent purchase (**54.19%**).
- **Recommended action:** Validate event collection and investigate checkout behavior before recommending a device-specific redesign. Test credible delivery-date information as a separate, explicitly hypothetical intervention.

## Data and metric definitions

Source: Google's public, obfuscated GA4 e-commerce sample in BigQuery:

```text
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
```

The analysis covers **November 1, 2020–January 31, 2021**.

| Definition | Meaning |
|---|---|
| Session | One `user_pseudo_id`–`ga_session_id` pair with non-null identifiers |
| Session date | Earliest recorded event date in that session |
| Session device | Device category from the earliest timestamped event |
| Purchasing session | A session containing at least one purchase event |
| Session purchase rate | Purchasing sessions divided by total sessions |
| Stage reach | Presence of a stage event anywhere in the session |
| Ordered funnel | Product view → cart → checkout → purchase with strictly increasing timestamps |
| Acquisition fields | The user's original acquisition source and medium; not session attribution |

The session data contains **270,154 distinct user IDs**. Repeat sessions motivate resampling users rather than treating every session as independent.

## Methods

1. Extract nested GA4 session identifiers and aggregate events to one row per user–session pair.
2. Validate totals and investigate users with repeated sessions.
3. Compare mobile and desktop purchase rates using a user-level bootstrap.
4. Adjust separately for calendar week and first-user medium to examine sensitivity to traffic composition. These are not a joint adjustment or a causal estimate.
5. Audit daily event coverage and distinguish event presence from ordered progression.
6. Construct a restricted ordered funnel using session dates and session device categories.
7. Develop hypothetical revenue scenarios and an experiment proposal with explicit sample-size assumptions.

## Restricted ordered funnel

**Population:** 246,106 mobile/desktop sessions dated December 1, 2020–January 31, 2021.

| Recorded ordered stage | Sessions |
|---|---:|
| Product view | 49,948 |
| Product view → cart | 12,019 |
| Product view → cart → checkout | 4,246 |
| Product view → cart → checkout → purchase | 2,301 |

There were **1,945** ordered checkout sessions without a subsequent same-session purchase. These are activity to investigate, not guaranteed recoverable orders or revenue.

Earlier exploratory SQL filtered individual event dates and produced slightly different counts. The final dashboard uses the session-based population above, consistent with the Python subset.

## Proposed experiment: delivery-date information

A current website review found no estimated arrival date for the default ground-shipping option. This observation comes from a different period than the historical dataset and cannot explain historical behavior by itself.

| Element | Proposal |
|---|---|
| Hypothesis | Credible arrival-date information reduces uncertainty and improves purchasing |
| Eligibility | Mobile/desktop users reaching shipping options with ground shipping and a credible estimate available |
| Control | Existing ground-shipping presentation |
| Treatment | Same presentation with a credible estimated arrival-date range |
| Assignment | 50/50 by user before shipping options appear; preserve assignment across visits |
| Primary metric | Share of eligible randomized users purchasing within seven days |
| Analysis population | All eligible randomized users, regardless of selected shipping method |
| Guardrails | Revenue per user, shipping-method mix, errors, cancellations, and delivery accuracy |

Shipping prices, service speeds, and default selection are held constant. Arrival estimates must reflect realistic fulfillment and transit times.

### Illustrative sample requirements

Assumptions: **50% user purchase baseline, 80% power, two-sided 5% significance, equal allocation**, and independent user outcomes.

| Absolute improvement | Total eligible users |
|---|---:|
| +0.5 percentage points | 313,944 |
| +1.0 percentage point | 78,480 |
| +2.0 percentage points | 19,612 |
| +3.0 percentage points | 8,712 |

For the +2-point scenario, **500 new eligible users per day** implies **42 enrollment days**, rounded to complete weeks, plus **seven days of purchase follow-up**.

These are planning scenarios, not forecasts. Before launch, measure the actual eligible-user baseline and enrollment traffic, and define the smallest economically worthwhile improvement. The historical session completion rate is not interchangeable with this seven-day user metric.

## Dashboard

The published workbook contains three pages:

- **Executive Overview:** Session KPIs, device comparison, weekly trend, and device filtering.
- **Funnel & Measurement:** Restricted ordered funnel and daily cart/checkout session coverage.
- **Experiment Proposal:** Delivery-date hypothesis, experimental design, and sample requirements.

## Project files

- `sql/` — BigQuery exploration, validation, reporting, and funnel queries.
- `notebook/python_analysis.ipynb` — Python analysis and experiment planning.
- `data/experiment_sample_sizes.csv` — Illustrative experiment sample requirements.
- `requirements.txt` — Python dependencies.

## How to reproduce

1. Download or clone this repository.
2. Run `sql/12_session_reporting_table.sql` in BigQuery using GoogleSQL.
3. Export all results as `Sessions.csv` and place it inside the `notebook/` folder. Expected total: 360,129 rows.
4. From a terminal in the repository's main folder, install dependencies:

   ```bash
   python3 -m pip install -r requirements.txt
   ```

5. Start JupyterLab:

   ```bash
   cd notebook
   python3 -m jupyterlab
   ```

6. Open `python_analysis.ipynb`, restart the kernel, and run all cells.

For the dashboard, run `sql/20_dashboard_session_funnel.sql`
and export the results as `Dashboard_sessions.csv`.

The notebook's original ordered-funnel results use event-date
filtering from query 19. The dashboard uses session-date filtering
from query 20, producing slightly different populations and counts.

### Reproduction workflow

1. Run the session reporting query in BigQuery using GoogleSQL and export **all rows** as `Sessions.csv`. The expected session total is **360,129**.
2. Once the notebook is included, place the CSV where its loading cell expects it and restart the kernel before running all cells.
3. Run the final dashboard session/funnel query to produce `Dashboard_sessions.csv`. Validate the restricted funnel against the counts above.
4. Use that export for the session-based Tableau sheets and `data/experiment_sample_sizes.csv` as a separate planning data source.

Detailed dependency installation and file-path instructions will be added with the notebook. BigQuery execution and Python results have not been rerun as part of this repository setup.

## Limitations

- This is obfuscated sample data from 2020–2021, not a current store-performance assessment.
- Missing cart events have an unknown cause. Excluding November does not establish complete December–January tracking.
- Strict timestamp order excludes ties and journeys spanning multiple sessions. Sessions are bounded by available dataset events.
- User IDs are pseudonymous identifiers, not guaranteed unique people across devices.
- Device comparisons are observational and do not establish causation.
- The first Monday-based calendar week contains only one dataset day.
- Revenue scenarios depend on transaction-audit exclusions and AOV assumptions. They are hypothetical, not measured incremental revenue.
- The proposed experiment has not been run; no conversion lift is claimed.

## Author

Ian Gaffney

