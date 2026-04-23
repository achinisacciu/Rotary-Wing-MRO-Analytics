# Rotary Wing MRO Analytics

An end-to-end data analytics project built on a helicopter fleet maintenance
domain, covering database design, SQL analytics and Power BI dashboards.

---

## Project Overview

This project simulates a real-world maintenance operations analytics system
for a helicopter fleet operating across multiple Italian bases.

The goal is to demonstrate full-stack data analytics skills:
- data modeling (conceptual, logical, physical);
- relational database design with PostgreSQL;
- SQL analytics with views and KPI queries;
- interactive dashboards with Power BI.

The project is structured in two iterations:

- **v1 — Corrective Maintenance**: anomaly tracking, work order management,
  SLA monitoring, backlog analysis and fleet reliability.
- **v2 — Workforce & Scheduled Maintenance**: individual technician
  assignments, capacity vs backlog analysis and preventive maintenance plan
  tracking with schedule compliance metrics.

---

## Business Questions

### v1 — Corrective Maintenance

**Efficiency**
- How long does it take to close a work order from opening?
- Are maintenance teams respecting SLA targets?
- Where does the process lose time (assignment, execution, waiting)?

**Reliability**
- Which assets generate the most anomalies?
- Which components are most frequently involved in critical events?
- Which assets have the highest estimated downtime?

**Organizational Performance**
- Which base has the highest maintenance backlog?
- Which team performs best on SLA and MTTR?
- How does fleet utilization evolve over time?

### v2 — Workforce & Scheduled Maintenance

**Workforce Analytics**
- Which technicians are overloaded or underutilized?
- How does actual capacity compare to active backlog per team?
- Where do individual task hours deviate most from estimates?

**Scheduled Maintenance**
- What is the corrective vs preventive split by base and period?
- Which scheduled interventions are overdue or have been deferred?
- How many weeks does each team need to absorb the current backlog?

---

## Stack

| Layer | Technology |
|---|---|
| Database | PostgreSQL 18 |
| Database Client | DataGrip (JetBrains) |
| Visualization | Power BI Desktop |
| Documentation | Markdown |

---

## Repository Structure

```
maintenance-analytics/
│
├── sql/
│   ├── schema.sql                  # v1 physical model: tables, constraints, indexes
│   ├── seed.sql                    # v1 demo dataset
│   ├── views.sql                   # v1 analytical views (12 views)
│   ├── schema_v2.sql               # v2 new tables and ALTER TABLE
│   ├── seed_v2.sql                 # v2 demo dataset (technicians, plans, assignments)
│   ├── views_v2.sql                # v2 analytical views (9 views)
│   └── test_queries.sql            # Validation and KPI queries
│
├── docs/
│   ├── modello_concettuale.md      # Conceptual model
│   ├── modello_logico.md           # Logical model v1
│   ├── modello_logico_v2.md        # Logical model v2 (updated with 5 new tables)
│   └── glossary.md                 # Domain glossary (v1 + v2 terms)
│
├── screenshots/
│   ├── dashboard_01_overview.png
│   ├── dashboard_02_reliability.png
│   ├── dashboard_03_performance.png
│   ├── dashboard_04_workforce.png
│   └── dashboard_05_scheduled_maintenance.png
│
└── README.md
```

---

## Data Model

For domain terminology, see [glossary](docs/glossary.md).

### v1 — 13 tables

**Master Data**
- `bases` — operational and maintenance bases
- `assets` — helicopter fleet registry
- `components_catalog` — component type catalog
- `teams` — maintenance team registry
- `task_catalog` — standard maintenance task catalog

**Events and Process**
- `anomalies` — technical events detected on assets
- `work_orders` — maintenance orders opened from anomalies *(field `maintenance_type` added in v2)*
- `work_order_tasks` — individual tasks within a work order

**History and Configuration**
- `asset_components` — component installation history per asset
- `asset_base_history` — asset assignment history per base
- `usage_logs` — daily flight hours and mission logs

**Bridge Tables**
- `task_required_components` — standard components required per task type
- `work_order_task_required_components` — actual components used per task

### v2 additions — 5 new tables

**Workforce**
- `technicians` — individual technician registry with specialization, certification and weekly hours
- `technician_availability` — absence and unavailability history per technician
- `work_order_task_assignments` — technician-to-task assignment with individual actual hours

**Scheduled Maintenance**
- `maintenance_plans` — preventive maintenance plan catalog (calendar, flight hours, cycles triggers)
- `scheduled_work_orders` — plan instances with status, deferral reason and compliance tracking

### Key design decisions

- Primary keys use `GENERATED ALWAYS AS IDENTITY` (PostgreSQL standard)
- `work_orders.team_id` is nullable to support the `open` status before assignment
- `asset_base_history` uses a partial unique index to enforce one current base per asset
- All temporal chains (opened → assigned → started → completed → closed) are protected by `CHECK` constraints
- `usage_logs` uses `NOT NULL DEFAULT 0` on counters to simplify analytical aggregations
- `work_order_task_assignments` has a `UNIQUE (work_order_task_id, technician_id)` constraint to prevent duplicate assignments
- `scheduled_work_orders` enforces `deferral_reason IS NOT NULL` when `status = 'deferred'` via `CHECK` constraint
- `maintenance_plans` requires at least one of `asset_id` or `asset_model` to be set

---

## Analytical Views

### v1 — 12 views

| View | Purpose |
|---|---|
| `v_kpi_wo_summary` | Global KPI cards: backlog, SLA %, MTTR, lead time |
| `v_wo_trend_mensile` | Monthly trend of open, closed and out-of-SLA work orders |
| `v_backlog_dettaglio` | Active backlog drill-down with overdue flag |
| `v_wo_stato_distribuzione` | Work order distribution by status |
| `v_asset_reliability` | Anomalies, downtime, flight hours per asset |
| `v_componenti_anomalie` | Components most involved in anomalies |
| `v_anomalie_severita_impatto` | Severity vs mission impact distribution |
| `v_task_performance` | Standard vs actual hours per task type |
| `v_base_performance` | KPI per base including coordinates for map visual |
| `v_team_performance` | Workload, SLA %, MTTR per team |
| `v_utilizzo_flotta_mensile` | Monthly fleet utilization per asset |
| `v_anomalie_trend_mensile` | Monthly anomaly trend by severity |

### v2 — 9 additional views

| View | Purpose |
|---|---|
| `v_technician_workload_mensile` | Monthly hours per technician with utilization rate |
| `v_technician_utilization` | Net available hours vs actual hours YTD per technician |
| `v_task_assignment_detail` | Task assignment drill-down with hours deviation flag |
| `v_team_capacity_vs_backlog` | Net team capacity vs active backlog in hours |
| `v_maintenance_type_split` | Corrective vs preventive split by base and period |
| `v_scheduled_wo_compliance` | Scheduled work orders with delay, status and deferral reason |
| `v_plan_coverage` | Active plans with estimated next due date per asset |
| `v_preventive_vs_corrective_trend` | Monthly side-by-side trend of both maintenance types |
| `v_asset_preventive_impact` | Correlation between preventive interventions and critical anomalies per asset |

---

## KPIs

### v1

| KPI | Definition |
|---|---|
| **MTTR** | Mean time from `started_at` to `completed_at` on work orders |
| **Lead Time** | Mean time from `opened_at` to `closed_at` |
| **SLA Compliance %** | % of closed work orders within `sla_hours` |
| **Time to Assign** | Mean time from `opened_at` to `assigned_at` |
| **Active Backlog** | Count of work orders with status open / assigned / in_progress / pending_parts |
| **Estimated Downtime** | Sum of `actual_total_hours` on closed work orders per asset |
| **Estimated vs Actual Hours** | Average deviation between estimated and actual hours |

### v2

| KPI | Definition |
|---|---|
| **Technician Utilization %** | Actual hours / net available hours per technician YTD |
| **Weeks to Clear Backlog** | Estimated backlog hours / net weekly team capacity |
| **Hours Deviation Flag** | `over` / `in_range` / `under` based on ±20% threshold vs estimated |
| **Schedule Compliance %** | % of scheduled work orders completed on or before planned date |
| **Deferral Rate** | % of scheduled work orders with status `deferred` |
| **Corrective vs Preventive Ratio** | Count and hours of corrective vs preventive WOs per period |
| **Critical Anomalies per Preventive** | Ratio of critical anomalies to completed preventive interventions per asset |

---

## Dataset

### v1 — covers October 2025 – March 2026

- 4 bases across Italy (Rome, Milan, Naples, Cagliari)
- 12 helicopters (AW139, AW169, AW189) across SAR, EMS and Offshore roles
- 12 component types
- 6 maintenance teams
- 12 standard task types
- 30 anomalies and 30 work orders (20 closed, 10 open/in progress)
- 43 work order tasks
- 114 component installation records
- 500 daily usage log entries

### v2 additions

- 20 technicians distributed across 6 teams (3–4 per team)
- 14 absence records covering leave, training, sick and detachment
- 28 task assignments covering work order tasks 24–43
- 10 maintenance plans (calendar and flight-hours triggers, AW139/AW169/AW189)
- 54 scheduled work orders spanning March 2025 – September 2026,
  with `completed`, `planned` and `deferred` statuses

---

## Author

**Andrea Palazzo**
Catania, Italy
[LinkedIn](https://www.linkedin.com/in/ndrplz) · [GitHub](https://github.com/achinisacciu)
