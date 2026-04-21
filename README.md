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

---

## Business Questions

The project answers the following operational questions:

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
```bash
maintenance-analytics/
│
├── sql/
│ ├── schema.sql # Physical model: tables, constraints, indexes
│ ├── seed.sql # Realistic demo dataset
│ ├── views.sql # Analytical views for Power BI
│ └── test_queries.sql # Validation and KPI queries
│
├── docs/
│ ├── modello_concettuale.md # Conceptual model
│ └── modello_logico.md # Logical model
│ └── glossary.md # Domain glossary
│
├── screenshots/
│ ├── dashboard_1.png
│ ├── dashboard_2.png
│ └── dashboard_3.png
│
└── README.md
```

---

## Data Model

For domain terminology, see [glossary](docs/glossary.md).

The physical model includes **13 tables** organized in 4 areas:

**Master Data**
- `bases` — operational and maintenance bases
- `assets` — helicopter fleet registry
- `components_catalog` — component type catalog
- `teams` — maintenance team registry
- `task_catalog` — standard maintenance task catalog

**Events and Process**
- `anomalies` — technical events detected on assets
- `work_orders` — maintenance orders opened from anomalies
- `work_order_tasks` — individual tasks within a work order

**History and Configuration**
- `asset_components` — component installation history per asset
- `asset_base_history` — asset assignment history per base
- `usage_logs` — daily flight hours and mission logs

**Bridge Tables**
- `task_required_components` — standard components required per task type
- `work_order_task_required_components` — actual components used per task

### Key design decisions

- Primary keys use `GENERATED ALWAYS AS IDENTITY` (PostgreSQL standard)
- `work_orders.team_id` is nullable to support the `open` status before assignment
- `asset_base_history` uses a partial unique index to enforce one current base per asset
- All temporal chains (opened → assigned → started → completed → closed) are protected by `CHECK` constraints
- `usage_logs` uses `NOT NULL DEFAULT 0` on counters to simplify analytical aggregations

---

## Analytical Views

12 views organized by dashboard:

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

---

## KPIs

| KPI | Definition |
|---|---|
| **MTTR** | Mean time from `started_at` to `completed_at` on work orders |
| **Lead Time** | Mean time from `opened_at` to `closed_at` |
| **SLA Compliance %** | % of closed work orders within `sla_hours` |
| **Time to Assign** | Mean time from `opened_at` to `assigned_at` |
| **Active Backlog** | Count of work orders with status open / assigned / in_progress / pending_parts |
| **Estimated Downtime** | Sum of `actual_total_hours` on closed work orders per asset |
| **Estimated vs Actual Hours** | Average deviation between estimated and actual hours |

---

## Dataset

The demo dataset covers a 6-month period (October 2025 – March 2026) and includes:

- 4 bases across Italy (Rome, Milan, Naples, Cagliari)
- 12 helicopters (AW139, AW169, AW189) across SAR, EMS and Offshore roles
- 12 component types
- 6 maintenance teams
- 12 standard task types
- 30 anomalies and 30 work orders (20 closed, 10 open)
- 43 work order tasks
- 114 component installation records
- 500 daily usage log entries

---

## Author

**Andrea Palazzo**  
Catania, Italy  
[LinkedIn](www.linkedin.com/in/ndrplz) · [GitHub](https://github.com/achinisacciu)
