-- ============================================
-- Test Queries: Maintenance Operations Analytics
-- Versione: 1.0
-- Data: 2026-04-19
-- DB target: maintenance_analytics
-- ============================================
-- Struttura:
--   BLOCCO 1 — Validazione integrità seed
--   BLOCCO 2 — KPI operativi principali
--   BLOCCO 3 — Analisi processo (SLA, lead time, backlog)
--   BLOCCO 4 — Affidabilità asset e componenti
--   BLOCCO 5 — Performance per base e team
-- ============================================


-- ============================================
-- BLOCCO 1 — VALIDAZIONE INTEGRITÀ SEED
-- ============================================
-- Queste query verificano che i dati siano stati inseriti correttamente
-- e che le relazioni tra le tabelle siano coerenti.

-- 1.1 Conteggio righe per tabella
SELECT 'bases'                               AS tabella, COUNT(*) AS righe FROM bases
UNION ALL
SELECT 'assets',                              COUNT(*) FROM assets
UNION ALL
SELECT 'components_catalog',                  COUNT(*) FROM components_catalog
UNION ALL
SELECT 'teams',                               COUNT(*) FROM teams
UNION ALL
SELECT 'task_catalog',                        COUNT(*) FROM task_catalog
UNION ALL
SELECT 'asset_components',                    COUNT(*) FROM asset_components
UNION ALL
SELECT 'asset_base_history',                  COUNT(*) FROM asset_base_history
UNION ALL
SELECT 'usage_logs',                          COUNT(*) FROM usage_logs
UNION ALL
SELECT 'anomalies',                           COUNT(*) FROM anomalies
UNION ALL
SELECT 'work_orders',                         COUNT(*) FROM work_orders
UNION ALL
SELECT 'work_order_tasks',                    COUNT(*) FROM work_order_tasks
UNION ALL
SELECT 'task_required_components',            COUNT(*) FROM task_required_components
ORDER BY tabella;


-- 1.2 Verifica che ogni work order abbia una anomalia collegata (nessun orfano)
SELECT
    wo.work_order_id,
    wo.work_order_code,
    wo.anomaly_id
FROM work_orders wo
LEFT JOIN anomalies a ON a.anomaly_id = wo.anomaly_id
WHERE a.anomaly_id IS NULL;
-- ATTESO: 0 righe


-- 1.3 Verifica che ogni work order task abbia un work order valido
SELECT
    wot.work_order_task_id,
    wot.work_order_id
FROM work_order_tasks wot
LEFT JOIN work_orders wo ON wo.work_order_id = wot.work_order_id
WHERE wo.work_order_id IS NULL;
-- ATTESO: 0 righe


-- 1.4 Verifica che ogni asset abbia almeno un componente installato
SELECT
    a.asset_id,
    a.asset_code,
    COUNT(ac.asset_component_id) AS componenti_installati
FROM assets a
LEFT JOIN asset_components ac ON ac.asset_id = a.asset_id
    AND ac.installation_status = 'installed'
GROUP BY a.asset_id, a.asset_code
ORDER BY componenti_installati ASC;
-- ATTESO: nessun asset con 0 componenti


-- 1.5 Verifica coerenza: nessun asset con più di una base corrente
SELECT
    asset_id,
    COUNT(*) AS righe_correnti
FROM asset_base_history
WHERE is_current_flag = TRUE
GROUP BY asset_id
HAVING COUNT(*) > 1;
-- ATTESO: 0 righe (garantito da partial unique index)


-- ============================================
-- BLOCCO 2 — KPI OPERATIVI PRINCIPALI
-- ============================================

-- 2.1 Totale work order per stato
SELECT
    work_order_status,
    COUNT(*)                        AS totale_wo,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS perc
FROM work_orders
GROUP BY work_order_status
ORDER BY totale_wo DESC;


-- 2.2 Backlog attivo: work order non chiusi
SELECT
    COUNT(*)                        AS backlog_totale,
    SUM(CASE WHEN work_order_status = 'open'         THEN 1 ELSE 0 END) AS open,
    SUM(CASE WHEN work_order_status = 'assigned'     THEN 1 ELSE 0 END) AS assigned,
    SUM(CASE WHEN work_order_status = 'in_progress'  THEN 1 ELSE 0 END) AS in_progress,
    SUM(CASE WHEN work_order_status = 'pending_parts'THEN 1 ELSE 0 END) AS pending_parts
FROM work_orders
WHERE work_order_status IN ('open', 'assigned', 'in_progress', 'pending_parts');


-- 2.3 Totale anomalie per severità e priorità
SELECT
    severity_level,
    priority_level,
    COUNT(*)                        AS totale
FROM anomalies
GROUP BY severity_level, priority_level
ORDER BY severity_level, priority_level;


-- 2.4 Distribuzione anomalie per impatto missione
SELECT
    mission_impact_level,
    COUNT(*)                        AS totale,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS perc
FROM anomalies
GROUP BY mission_impact_level
ORDER BY totale DESC;


-- 2.5 Work order: confronto ore stimate vs ore reali (solo chiusi)
SELECT
    ROUND(AVG(estimated_total_hours), 2)                    AS media_ore_stimate,
    ROUND(AVG(actual_total_hours), 2)                       AS media_ore_reali,
    ROUND(AVG(actual_total_hours - estimated_total_hours), 2) AS scostamento_medio,
    ROUND(100.0 * AVG(actual_total_hours) / NULLIF(AVG(estimated_total_hours), 0), 1) AS perc_reale_su_stima
FROM work_orders
WHERE work_order_status IN ('completed', 'closed')
  AND estimated_total_hours IS NOT NULL
  AND actual_total_hours IS NOT NULL;


-- ============================================
-- BLOCCO 3 — ANALISI PROCESSO (SLA, LEAD TIME, BACKLOG)
-- ============================================

-- 3.1 Lead time medio di chiusura work order (ore)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600), 2) AS lead_time_medio_ore,
    ROUND(MIN(EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600), 2) AS lead_time_min_ore,
    ROUND(MAX(EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600), 2) AS lead_time_max_ore
FROM work_orders
WHERE work_order_status = 'closed'
  AND closed_at IS NOT NULL
  AND opened_at IS NOT NULL;


-- 3.2 Tempo medio di presa in carico (da apertura WO ad assegnazione)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (assigned_at - opened_at)) / 3600), 2) AS tempo_medio_presa_incarico_ore
FROM work_orders
WHERE assigned_at IS NOT NULL
  AND opened_at IS NOT NULL;


-- 3.3 MTTR: tempo medio di riparazione (da started_at a completed_at)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600), 2) AS mttr_medio_ore
FROM work_orders
WHERE started_at IS NOT NULL
  AND completed_at IS NOT NULL;


-- 3.4 Work order fuori SLA (chiusi oltre il tempo target)
SELECT
    wo.work_order_id,
    wo.work_order_code,
    wo.sla_hours,
    ROUND(EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600, 2)  AS ore_effettive,
    ROUND(EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 - wo.sla_hours, 2) AS sforamento_ore,
    a.severity_level,
    a.priority_level
FROM work_orders wo
JOIN anomalies a ON a.anomaly_id = wo.anomaly_id
WHERE wo.work_order_status = 'closed'
  AND wo.closed_at IS NOT NULL
  AND wo.sla_hours IS NOT NULL
  AND EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 > wo.sla_hours
ORDER BY sforamento_ore DESC;


-- 3.5 Percentuale work order chiusi rispettando lo SLA
SELECT
    COUNT(*)                                                            AS totale_chiusi,
    SUM(CASE
        WHEN EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600 <= sla_hours THEN 1
        ELSE 0
    END)                                                                AS entro_sla,
    SUM(CASE
        WHEN EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600 > sla_hours THEN 1
        ELSE 0
    END)                                                                AS fuori_sla,
    ROUND(100.0 * SUM(CASE
        WHEN EXTRACT(EPOCH FROM (closed_at - opened_at)) / 3600 <= sla_hours THEN 1
        ELSE 0
    END) / NULLIF(COUNT(*), 0), 1)                                      AS perc_entro_sla
FROM work_orders
WHERE work_order_status = 'closed'
  AND closed_at IS NOT NULL
  AND sla_hours IS NOT NULL;


-- ============================================
-- BLOCCO 4 — AFFIDABILITÀ ASSET E COMPONENTI
-- ============================================

-- 4.1 Asset con più anomalie (top 10)
SELECT
    a.asset_id,
    a.asset_code,
    a.model,
    b.base_name,
    COUNT(ano.anomaly_id)           AS totale_anomalie,
    SUM(CASE WHEN ano.severity_level IN ('high', 'critical') THEN 1 ELSE 0 END) AS anomalie_gravi
FROM assets a
JOIN bases b ON b.base_id = a.current_base_id
LEFT JOIN anomalies ano ON ano.asset_id = a.asset_id
GROUP BY a.asset_id, a.asset_code, a.model, b.base_name
ORDER BY totale_anomalie DESC
LIMIT 10;


-- 4.2 Componenti più coinvolti nelle anomalie
SELECT
    cc.component_type_id,
    cc.component_code,
    cc.component_name,
    cc.component_category,
    cc.criticality_level,
    COUNT(ano.anomaly_id)           AS anomalie_collegate
FROM components_catalog cc
LEFT JOIN anomalies ano ON ano.affected_component_type_id = cc.component_type_id
GROUP BY cc.component_type_id, cc.component_code, cc.component_name,
         cc.component_category, cc.criticality_level
ORDER BY anomalie_collegate DESC;


-- 4.3 Downtime stimato per asset (somma ore effettive dei WO chiusi per asset)
SELECT
    a.asset_id,
    a.asset_code,
    a.model,
    ROUND(SUM(wo.actual_total_hours), 2)    AS downtime_stimato_ore,
    COUNT(wo.work_order_id)                 AS interventi_totali
FROM assets a
JOIN anomalies ano ON ano.asset_id = a.asset_id
JOIN work_orders wo ON wo.anomaly_id = ano.anomaly_id
WHERE wo.work_order_status IN ('completed', 'closed')
  AND wo.actual_total_hours IS NOT NULL
GROUP BY a.asset_id, a.asset_code, a.model
ORDER BY downtime_stimato_ore DESC;


-- 4.4 Task più frequenti nei work order
SELECT
    tc.task_template_id,
    tc.task_code,
    tc.task_name,
    tc.task_category,
    tc.standard_duration_hours,
    COUNT(wot.work_order_task_id)           AS volte_eseguita,
    ROUND(AVG(wot.actual_hours), 2)         AS ore_reali_medie,
    ROUND(AVG(wot.actual_hours) - tc.standard_duration_hours, 2) AS scostamento_medio
FROM task_catalog tc
LEFT JOIN work_order_tasks wot ON wot.task_template_id = tc.task_template_id
    AND wot.task_status = 'completed'
GROUP BY tc.task_template_id, tc.task_code, tc.task_name,
         tc.task_category, tc.standard_duration_hours
ORDER BY volte_eseguita DESC;


-- ============================================
-- BLOCCO 5 — PERFORMANCE PER BASE E TEAM
-- ============================================

-- 5.1 Work order per base (tramite team assegnato)
SELECT
    b.base_id,
    b.base_name,
    COUNT(wo.work_order_id)                 AS totale_wo,
    SUM(CASE WHEN wo.work_order_status IN ('open','assigned','in_progress','pending_parts') THEN 1 ELSE 0 END) AS backlog,
    SUM(CASE WHEN wo.work_order_status = 'closed' THEN 1 ELSE 0 END) AS chiusi,
    ROUND(AVG(CASE WHEN wo.work_order_status = 'closed'
        THEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600
        ELSE NULL END), 2)                  AS lead_time_medio_ore
FROM bases b
LEFT JOIN teams t ON t.base_id = b.base_id
LEFT JOIN work_orders wo ON wo.team_id = t.team_id
GROUP BY b.base_id, b.base_name
ORDER BY totale_wo DESC;


-- 5.2 Workload per team: WO assegnati, backlog e lead time
SELECT
    t.team_id,
    t.team_code,
    t.team_name,
    b.base_name,
    COUNT(wo.work_order_id)                 AS totale_wo_assegnati,
    SUM(CASE WHEN wo.work_order_status IN ('open','assigned','in_progress','pending_parts') THEN 1 ELSE 0 END) AS backlog_attivo,
    ROUND(AVG(CASE WHEN wo.work_order_status = 'closed'
        THEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600
        ELSE NULL END), 2)                  AS lead_time_medio_ore
FROM teams t
JOIN bases b ON b.base_id = t.base_id
LEFT JOIN work_orders wo ON wo.team_id = t.team_id
GROUP BY t.team_id, t.team_code, t.team_name, b.base_name
ORDER BY totale_wo_assegnati DESC;


-- 5.3 SLA compliance per team
SELECT
    t.team_code,
    t.team_name,
    COUNT(wo.work_order_id)                 AS wo_chiusi,
    SUM(CASE WHEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 <= wo.sla_hours THEN 1 ELSE 0 END) AS entro_sla,
    SUM(CASE WHEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 > wo.sla_hours  THEN 1 ELSE 0 END) AS fuori_sla,
    ROUND(100.0 * SUM(CASE WHEN EXTRACT(EPOCH FROM (wo.closed_at - wo.opened_at)) / 3600 <= wo.sla_hours THEN 1 ELSE 0 END)
        / NULLIF(COUNT(wo.work_order_id), 0), 1)                        AS perc_entro_sla
FROM teams t
JOIN work_orders wo ON wo.team_id = t.team_id
WHERE wo.work_order_status = 'closed'
  AND wo.closed_at IS NOT NULL
  AND wo.sla_hours IS NOT NULL
GROUP BY t.team_code, t.team_name
ORDER BY perc_entro_sla DESC;


-- 5.4 Anomalie per base dell'asset (quante anomalie per ogni base operativa)
SELECT
    b.base_id,
    b.base_name,
    COUNT(ano.anomaly_id)                   AS totale_anomalie,
    SUM(CASE WHEN ano.severity_level = 'critical' THEN 1 ELSE 0 END)   AS critiche,
    SUM(CASE WHEN ano.severity_level = 'high'     THEN 1 ELSE 0 END)   AS alte,
    SUM(CASE WHEN ano.priority_level = 'urgent'   THEN 1 ELSE 0 END)   AS urgenti
FROM bases b
JOIN assets a ON a.current_base_id = b.base_id
JOIN anomalies ano ON ano.asset_id = a.asset_id
GROUP BY b.base_id, b.base_name
ORDER BY totale_anomalie DESC;


-- 5.5 Utilizzo flotta: ore di volo totali per asset (sui dati seed disponibili)
SELECT
    a.asset_id,
    a.asset_code,
    a.model,
    b.base_name,
    ROUND(SUM(ul.flight_hours), 2)          AS ore_volo_totali,
    SUM(ul.missions_count)                  AS missioni_totali,
    SUM(ul.critical_missions_count)         AS missioni_critiche,
    COUNT(ul.usage_log_id)                  AS giorni_registrati
FROM assets a
JOIN bases b ON b.base_id = a.current_base_id
LEFT JOIN usage_logs ul ON ul.asset_id = a.asset_id
GROUP BY a.asset_id, a.asset_code, a.model, b.base_name
ORDER BY ore_volo_totali DESC NULLS LAST;
