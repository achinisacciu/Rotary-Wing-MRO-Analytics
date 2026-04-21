-- ============================================
-- Views: Maintenance Operations Analytics
-- Versione: 1.0
-- Data: 2026-04-19
-- DB target: maintenance_analytics
-- ============================================
-- Struttura:
--   BLOCCO 1 — Dashboard 1: Operational Overview
--   BLOCCO 2 — Dashboard 2: Fleet Reliability
--   BLOCCO 3 — Dashboard 3: Base & Team Performance
-- ============================================


-- ============================================
-- BLOCCO 1 — OPERATIONAL OVERVIEW
-- ============================================

-- v_kpi_wo_summary
-- KPI aggregati globali sui work order: backlog, SLA, MTTR, lead time.
-- Usata per le card numeriche di sintesi nella dashboard 1.
CREATE OR REPLACE VIEW v_kpi_wo_summary AS
SELECT
    COUNT(*)                                                                AS totale_wo,

    SUM(CASE WHEN work_order_status IN ('open','assigned','in_progress','pending_parts')
        THEN 1 ELSE 0 END)                                                  AS backlog_attivo,

    SUM(CASE WHEN work_order_status IN ('completed','closed')
        THEN 1 ELSE 0 END)                                                  AS wo_chiusi,

    -- SLA compliance
    ROUND(
        100.0 * SUM(CASE
            WHEN work_order_status = 'closed'
             AND closed_at IS NOT NULL
             AND sla_hours IS NOT NULL
             AND EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600 <= sla_hours
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE
            WHEN work_order_status = 'closed'
             AND closed_at IS NOT NULL
             AND sla_hours IS NOT NULL
            THEN 1 ELSE 0 END), 0),
    1)                                                                      AS sla_compliance_perc,

    -- MTTR: dal momento in cui si inizia a lavorare a quando si finisce
    ROUND(AVG(CASE
        WHEN started_at IS NOT NULL AND completed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS mttr_medio_ore,

    -- Lead time: dal momento dell'apertura alla chiusura
    ROUND(AVG(CASE
        WHEN work_order_status = 'closed' AND closed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS lead_time_medio_ore,

    -- Tempo medio presa in carico
    ROUND(AVG(CASE
        WHEN assigned_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (assigned_at - opened_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS tempo_medio_presa_incarico_ore,

    -- Scostamento ore stimate vs reali
    ROUND(AVG(CASE
        WHEN estimated_total_hours IS NOT NULL AND actual_total_hours IS NOT NULL
        THEN actual_total_hours - estimated_total_hours
        ELSE NULL END),
    2)                                                                      AS scostamento_medio_ore

FROM work_orders;


-- v_wo_trend_mensile
-- Andamento mensile dei work order: aperti, chiusi, fuori SLA.
-- Usata per il grafico a linee o barre nella dashboard 1.
CREATE OR REPLACE VIEW v_wo_trend_mensile AS
SELECT
    DATE_TRUNC('month', opened_at)                                          AS mese,
    TO_CHAR(DATE_TRUNC('month', opened_at), 'YYYY-MM')                      AS mese_label,
    COUNT(*)                                                                AS wo_aperti,
    SUM(CASE WHEN work_order_status IN ('completed','closed') THEN 1 ELSE 0 END) AS wo_chiusi,
    SUM(CASE
        WHEN work_order_status = 'closed'
         AND closed_at IS NOT NULL
         AND sla_hours IS NOT NULL
         AND EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600 > sla_hours
        THEN 1 ELSE 0 END)                                                  AS wo_fuori_sla,
    ROUND(AVG(CASE
        WHEN work_order_status = 'closed' AND closed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS lead_time_medio_ore
FROM work_orders
GROUP BY DATE_TRUNC('month', opened_at)
ORDER BY mese;


-- v_backlog_dettaglio
-- Dettaglio work order attivi nel backlog con anomalia, asset e severità.
-- Usata per la tabella drill-down nella dashboard 1.
CREATE OR REPLACE VIEW v_backlog_dettaglio AS
SELECT
    wo.work_order_id,
    wo.work_order_code,
    wo.work_order_status,
    wo.opened_at,
    wo.due_at,
    ROUND(EXTRACT(EPOCH FROM (NOW() - wo.opened_at)) / 3600, 1)            AS ore_in_backlog,
    CASE
        WHEN wo.due_at IS NOT NULL AND NOW() > wo.due_at THEN TRUE
        ELSE FALSE
    END                                                                     AS scaduto,
    wo.sla_hours,
    a.anomaly_code,
    a.severity_level,
    a.priority_level,
    a.mission_impact_level,
    ast.asset_code,
    ast.model,
    b.base_name,
    t.team_name
FROM work_orders wo
JOIN anomalies a   ON a.anomaly_id   = wo.anomaly_id
JOIN assets ast    ON ast.asset_id   = a.asset_id
JOIN bases b       ON b.base_id      = ast.current_base_id
LEFT JOIN teams t  ON t.team_id      = wo.team_id
WHERE wo.work_order_status IN ('open','assigned','in_progress','pending_parts')
ORDER BY a.priority_level DESC, wo.opened_at ASC;


-- v_wo_stato_distribuzione
-- Distribuzione percentuale dei work order per stato.
-- Usata per il grafico a torta / donut nella dashboard 1.
CREATE OR REPLACE VIEW v_wo_stato_distribuzione AS
SELECT
    work_order_status,
    COUNT(*)                                                                AS totale,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                     AS percentuale
FROM work_orders
GROUP BY work_order_status
ORDER BY totale DESC;


-- ============================================
-- BLOCCO 2 — FLEET RELIABILITY
-- ============================================

-- v_asset_reliability
-- Per ogni asset: anomalie totali, critiche, downtime stimato, ore di volo.
-- Usata per la tabella principale e i grafici a barre nella dashboard 2.
CREATE OR REPLACE VIEW v_asset_reliability AS
SELECT
    ast.asset_id,
    ast.asset_code,
    ast.model,
    ast.asset_status,
    ast.mission_role,
    b.base_name,

    COUNT(DISTINCT ano.anomaly_id)                                          AS anomalie_totali,
    SUM(CASE WHEN ano.severity_level = 'critical' THEN 1 ELSE 0 END)       AS anomalie_critiche,
    SUM(CASE WHEN ano.severity_level = 'high'     THEN 1 ELSE 0 END)       AS anomalie_alte,
    SUM(CASE WHEN ano.mission_impact_level IN ('high','grounding') THEN 1 ELSE 0 END) AS impatto_missione_alto,

    -- Downtime stimato: somma ore reali dei WO chiusi collegati all'asset
    ROUND(COALESCE(SUM(CASE
        WHEN wo.work_order_status IN ('completed','closed')
        THEN wo.actual_total_hours ELSE NULL END), 0),
    2)                                                                      AS downtime_stimato_ore,

    -- Utilizzo dalla tabella usage_logs
    ROUND(COALESCE(SUM(ul.flight_hours), 0), 2)                            AS ore_volo_totali,
    COALESCE(SUM(ul.missions_count), 0)                                     AS missioni_totali,
    COALESCE(SUM(ul.critical_missions_count), 0)                            AS missioni_critiche

FROM assets ast
JOIN bases b ON b.base_id = ast.current_base_id
LEFT JOIN anomalies ano ON ano.asset_id = ast.asset_id
LEFT JOIN work_orders wo ON wo.anomaly_id = ano.anomaly_id
LEFT JOIN usage_logs ul ON ul.asset_id = ast.asset_id
GROUP BY ast.asset_id, ast.asset_code, ast.model, ast.asset_status,
         ast.mission_role, b.base_name
ORDER BY anomalie_totali DESC;


-- v_componenti_anomalie
-- Componenti più coinvolti nelle anomalie, con categoria e criticità.
-- Usata per il treemap o bar chart nella dashboard 2.
CREATE OR REPLACE VIEW v_componenti_anomalie AS
SELECT
    cc.component_type_id,
    cc.component_code,
    cc.component_name,
    cc.component_category,
    cc.criticality_level,
    COUNT(ano.anomaly_id)                                                   AS anomalie_totali,
    SUM(CASE WHEN ano.severity_level = 'critical' THEN 1 ELSE 0 END)       AS anomalie_critiche,
    SUM(CASE WHEN ano.severity_level = 'high'     THEN 1 ELSE 0 END)       AS anomalie_alte,
    SUM(CASE WHEN ano.priority_level = 'urgent'   THEN 1 ELSE 0 END)       AS priorita_urgenti
FROM components_catalog cc
LEFT JOIN anomalies ano ON ano.affected_component_type_id = cc.component_type_id
GROUP BY cc.component_type_id, cc.component_code, cc.component_name,
         cc.component_category, cc.criticality_level
ORDER BY anomalie_totali DESC;


-- v_anomalie_severita_impatto
-- Distribuzione anomalie per severità e impatto missione.
-- Usata per heatmap o grouped bar nella dashboard 2.
CREATE OR REPLACE VIEW v_anomalie_severita_impatto AS
SELECT
    severity_level,
    mission_impact_level,
    COUNT(*)                                                                AS totale,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                     AS percentuale
FROM anomalies
GROUP BY severity_level, mission_impact_level
ORDER BY severity_level, mission_impact_level;


-- v_task_performance
-- Confronto tra ore stimate (da catalogo) e ore reali per ogni tipo di task.
-- Usata per grafici di scostamento nella dashboard 2.
CREATE OR REPLACE VIEW v_task_performance AS
SELECT
    tc.task_template_id,
    tc.task_code,
    tc.task_name,
    tc.task_category,
    tc.complexity_level,
    tc.standard_duration_hours,
    COUNT(wot.work_order_task_id)                                           AS esecuzioni_totali,
    ROUND(AVG(wot.actual_hours), 2)                                         AS ore_reali_medie,
    ROUND(AVG(wot.actual_hours) - tc.standard_duration_hours, 2)            AS scostamento_medio,
    ROUND(100.0 * AVG(wot.actual_hours) / NULLIF(tc.standard_duration_hours, 0), 1) AS perc_reale_su_standard
FROM task_catalog tc
LEFT JOIN work_order_tasks wot ON wot.task_template_id = tc.task_template_id
    AND wot.task_status = 'completed'
GROUP BY tc.task_template_id, tc.task_code, tc.task_name,
         tc.task_category, tc.complexity_level, tc.standard_duration_hours
ORDER BY esecuzioni_totali DESC;


-- ============================================
-- BLOCCO 3 — BASE & TEAM PERFORMANCE
-- ============================================

-- v_base_performance
-- KPI aggregati per base: WO totali, backlog, SLA compliance, lead time.
-- Usata per la mappa o il bar chart nella dashboard 3.
CREATE OR REPLACE VIEW v_base_performance AS
SELECT
    b.base_id,
    b.base_name,
    b.city,
    b.region,
    b.latitude,
    b.longitude,
    b.maintenance_level,

    COUNT(DISTINCT wo.work_order_id)                                        AS wo_totali,
    SUM(CASE WHEN wo.work_order_status IN ('open','assigned','in_progress','pending_parts')
        THEN 1 ELSE 0 END)                                                  AS backlog_attivo,
    SUM(CASE WHEN wo.work_order_status IN ('completed','closed')
        THEN 1 ELSE 0 END)                                                  AS wo_chiusi,

    ROUND(
        100.0 * SUM(CASE
            WHEN wo.work_order_status = 'closed'
             AND wo.closed_at IS NOT NULL
             AND wo.sla_hours IS NOT NULL
             AND EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 <= wo.sla_hours
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE
            WHEN wo.work_order_status = 'closed'
             AND wo.closed_at IS NOT NULL
             AND wo.sla_hours IS NOT NULL
            THEN 1 ELSE 0 END), 0),
    1)                                                                      AS sla_compliance_perc,

    ROUND(AVG(CASE
        WHEN wo.work_order_status = 'closed' AND wo.closed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS lead_time_medio_ore,

    COUNT(DISTINCT ast.asset_id)                                            AS asset_totali,
    SUM(CASE WHEN ast.asset_status = 'operational' THEN 1 ELSE 0 END)      AS asset_operativi

FROM bases b
LEFT JOIN teams t     ON t.base_id  = b.base_id
LEFT JOIN work_orders wo ON wo.team_id = t.team_id
LEFT JOIN assets ast  ON ast.current_base_id = b.base_id
GROUP BY b.base_id, b.base_name, b.city, b.region, b.latitude, b.longitude, b.maintenance_level
ORDER BY wo_totali DESC;


-- v_team_performance
-- KPI per team: WO assegnati, backlog, SLA compliance, MTTR, scostamento ore.
-- Usata per la tabella comparativa nella dashboard 3.
CREATE OR REPLACE VIEW v_team_performance AS
SELECT
    t.team_id,
    t.team_code,
    t.team_name,
    t.specialization,
    t.capacity_level,
    b.base_name,

    COUNT(wo.work_order_id)                                                 AS wo_assegnati,
    SUM(CASE WHEN wo.work_order_status IN ('open','assigned','in_progress','pending_parts')
        THEN 1 ELSE 0 END)                                                  AS backlog_attivo,

    ROUND(
        100.0 * SUM(CASE
            WHEN wo.work_order_status = 'closed'
             AND wo.closed_at IS NOT NULL
             AND wo.sla_hours IS NOT NULL
             AND EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 <= wo.sla_hours
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE
            WHEN wo.work_order_status = 'closed'
             AND wo.closed_at IS NOT NULL
             AND wo.sla_hours IS NOT NULL
            THEN 1 ELSE 0 END), 0),
    1)                                                                      AS sla_compliance_perc,

    ROUND(AVG(CASE
        WHEN wo.started_at IS NOT NULL AND wo.completed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (wo.completed_at - wo.started_at)) / 3600
        ELSE NULL END),
    2)                                                                      AS mttr_medio_ore,

    ROUND(AVG(CASE
        WHEN wo.estimated_total_hours IS NOT NULL AND wo.actual_total_hours IS NOT NULL
        THEN wo.actual_total_hours - wo.estimated_total_hours
        ELSE NULL END),
    2)                                                                      AS scostamento_medio_ore

FROM teams t
JOIN bases b ON b.base_id = t.base_id
LEFT JOIN work_orders wo ON wo.team_id = t.team_id
GROUP BY t.team_id, t.team_code, t.team_name,
         t.specialization, t.capacity_level, b.base_name
ORDER BY wo_assegnati DESC;


-- v_utilizzo_flotta_mensile
-- Ore di volo e missioni per asset per mese.
-- Usata per il grafico a linee di utilizzo nella dashboard 3.
CREATE OR REPLACE VIEW v_utilizzo_flotta_mensile AS
SELECT
    DATE_TRUNC('month', ul.usage_date)                                      AS mese,
    TO_CHAR(DATE_TRUNC('month', ul.usage_date), 'YYYY-MM')                  AS mese_label,
    ast.asset_id,
    ast.asset_code,
    ast.model,
    ast.mission_role,
    b.base_name,
    ROUND(SUM(ul.flight_hours), 2)                                          AS ore_volo,
    SUM(ul.missions_count)                                                  AS missioni,
    SUM(ul.critical_missions_count)                                         AS missioni_critiche,
    SUM(ul.operational_days)                                                AS giorni_operativi
FROM usage_logs ul
JOIN assets ast ON ast.asset_id = ul.asset_id
JOIN bases b    ON b.base_id    = ast.current_base_id
GROUP BY DATE_TRUNC('month', ul.usage_date), ast.asset_id,
         ast.asset_code, ast.model, ast.mission_role, b.base_name
ORDER BY mese, ast.asset_code;


-- v_anomalie_trend_mensile
-- Numero anomalie per mese e severità.
-- Usata per il grafico a barre stacked nella dashboard 3.
CREATE OR REPLACE VIEW v_anomalie_trend_mensile AS
SELECT
    DATE_TRUNC('month', detected_at)                                        AS mese,
    TO_CHAR(DATE_TRUNC('month', detected_at), 'YYYY-MM')                    AS mese_label,
    severity_level,
    COUNT(*)                                                                AS anomalie
FROM anomalies
GROUP BY DATE_TRUNC('month', detected_at), severity_level
ORDER BY mese, severity_level;
