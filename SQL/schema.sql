-- ============================================
-- Database: Maintenance Operations Analytics
-- Versione: 2.0 — consolidata e corretta
-- Data: 2026-04-19
-- DB target: maintenance_analytics
-- ============================================




-- ============================================
-- TABELLE ANAGRAFICHE
-- ============================================

CREATE TABLE bases (
    base_id         INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    base_code       VARCHAR(50)     NOT NULL UNIQUE,
    base_name       VARCHAR(255)    NOT NULL,
    address         VARCHAR(500),
    city            VARCHAR(100),
    region          VARCHAR(100),
    country         VARCHAR(100),

    -- DECIMAL(10,7) copre latitudine [-90, 90]: 2 cifre intere + 7 decimali
    -- DECIMAL(11,7) copre longitudine [-180, 180]: 3 cifre intere + 7 decimali
    latitude        DECIMAL(10, 7),
    longitude       DECIMAL(11, 7),

    maintenance_level VARCHAR(50),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive'))
);


CREATE TABLE assets (
    asset_id                INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_code              VARCHAR(50)     NOT NULL UNIQUE,
    serial_number           VARCHAR(100)    NOT NULL UNIQUE,
    model                   VARCHAR(255)    NOT NULL,
    manufacturer            VARCHAR(255),
    manufacture_year        INTEGER
        CHECK (manufacture_year IS NULL OR (manufacture_year >= 1900 AND manufacture_year <= 2100)),
    entry_into_service_date DATE,
    current_base_id         INTEGER         NOT NULL REFERENCES bases(base_id),
    asset_status            VARCHAR(30)     NOT NULL DEFAULT 'operational'
        CHECK (asset_status IN ('operational', 'maintenance', 'grounded', 'retired')),
    mission_role            VARCHAR(100)
);


CREATE TABLE components_catalog (
    component_type_id           INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_code              VARCHAR(50)     NOT NULL UNIQUE,
    component_name              VARCHAR(255)    NOT NULL,
    component_category          VARCHAR(100)    NOT NULL,
    criticality_level           VARCHAR(20)
        CHECK (criticality_level IN ('low', 'medium', 'high', 'critical')),
    vendor                      VARCHAR(255),
    standard_replacement_hours  DECIMAL(6, 2)
        CHECK (standard_replacement_hours IS NULL OR standard_replacement_hours >= 0),
    is_repairable               BOOLEAN         DEFAULT TRUE
);


CREATE TABLE teams (
    team_id         INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_code       VARCHAR(50)     NOT NULL UNIQUE,
    team_name       VARCHAR(255)    NOT NULL,
    base_id         INTEGER         NOT NULL REFERENCES bases(base_id),
    specialization  VARCHAR(100),
    capacity_level  VARCHAR(20)
        CHECK (capacity_level IN ('junior', 'mid', 'senior', 'expert')),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive'))
);


CREATE TABLE task_catalog (
    task_template_id        INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_code               VARCHAR(50)     NOT NULL UNIQUE,
    task_name               VARCHAR(255)    NOT NULL,
    task_category           VARCHAR(100),
    standard_duration_hours DECIMAL(6, 2)   NOT NULL
        CHECK (standard_duration_hours > 0),
    complexity_level        VARCHAR(20)
        CHECK (complexity_level IN ('low', 'medium', 'high', 'critical')),
    requires_shutdown_flag  BOOLEAN         DEFAULT FALSE,
    description             TEXT
);


-- ============================================
-- TABELLE EVENTO E PROCESSO
-- ============================================

CREATE TABLE anomalies (
    anomaly_id              INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    anomaly_code            VARCHAR(50)     NOT NULL UNIQUE,
    asset_id                INTEGER         NOT NULL REFERENCES assets(asset_id),
    detected_at             TIMESTAMP       NOT NULL,

    -- Una segnalazione non può precedere il momento di rilevazione
    reported_at             TIMESTAMP
        CHECK (reported_at IS NULL OR reported_at >= detected_at),

    severity_level          VARCHAR(20)     NOT NULL
        CHECK (severity_level IN ('low', 'medium', 'high', 'critical')),
    priority_level          VARCHAR(20)     NOT NULL
        CHECK (priority_level IN ('low', 'medium', 'high', 'urgent')),
    anomaly_status          VARCHAR(30)     NOT NULL DEFAULT 'open'
        CHECK (anomaly_status IN ('open', 'investigating', 'workorder_created', 'resolved', 'closed')),
    affected_component_type_id INTEGER       REFERENCES components_catalog(component_type_id),
    symptom_description     TEXT,
    mission_impact_level    VARCHAR(20)
        CHECK (mission_impact_level IN ('none', 'low', 'medium', 'high', 'grounding'))
);


CREATE TABLE work_orders (
    work_order_id       INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    work_order_code     VARCHAR(50)     NOT NULL UNIQUE,
    anomaly_id          INTEGER         NOT NULL UNIQUE REFERENCES anomalies(anomaly_id),

    -- team_id è nullable per consentire lo stato 'open' precedente all'assegnazione.
    -- Diventa NOT NULL quando il work order transisce in stato 'assigned'.
    -- Questa coerenza è responsabilità del layer applicativo o di un trigger futuro.
    team_id             INTEGER         REFERENCES teams(team_id),

    opened_at           TIMESTAMP       NOT NULL,
    assigned_at         TIMESTAMP,
    due_at              TIMESTAMP,
    started_at          TIMESTAMP,
    completed_at        TIMESTAMP,
    closed_at           TIMESTAMP,
    work_order_status   VARCHAR(30)     NOT NULL DEFAULT 'open'
        CHECK (work_order_status IN ('open', 'assigned', 'in_progress', 'pending_parts', 'completed', 'closed', 'cancelled')),
    sla_hours           DECIMAL(6, 2)
        CHECK (sla_hours IS NULL OR sla_hours >= 0),
    estimated_total_hours DECIMAL(6, 2)
        CHECK (estimated_total_hours IS NULL OR estimated_total_hours >= 0),
    actual_total_hours  DECIMAL(6, 2)
        CHECK (actual_total_hours IS NULL OR actual_total_hours >= 0),

    -- Catena temporale: ogni fase non può precedere la precedente
    CONSTRAINT chk_work_orders_assigned_after_opened
        CHECK (assigned_at IS NULL OR assigned_at >= opened_at),

    CONSTRAINT chk_work_orders_started_after_opened
        CHECK (started_at IS NULL OR started_at >= opened_at),

    CONSTRAINT chk_work_orders_completed_after_started
        CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at),

    CONSTRAINT chk_work_orders_closed_after_completed
        CHECK (closed_at IS NULL OR completed_at IS NULL OR closed_at >= completed_at),

    -- Se il team è assegnato, deve esserci anche assigned_at e viceversa
    CONSTRAINT chk_work_orders_team_assignment_coherence
        CHECK (
            (team_id IS NULL AND assigned_at IS NULL) OR
            (team_id IS NOT NULL AND assigned_at IS NOT NULL)
        )
);


CREATE TABLE work_order_tasks (
    work_order_task_id  INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    work_order_id       INTEGER         NOT NULL REFERENCES work_orders(work_order_id),
    task_template_id    INTEGER         NOT NULL REFERENCES task_catalog(task_template_id),

    -- Il numero di sequenza deve essere un intero positivo
    sequence_number     INTEGER         NOT NULL
        CHECK (sequence_number > 0),

    task_status         VARCHAR(30)     NOT NULL DEFAULT 'pending'
        CHECK (task_status IN ('pending', 'in_progress', 'completed', 'skipped', 'blocked')),
    estimated_hours     DECIMAL(6, 2)
        CHECK (estimated_hours IS NULL OR estimated_hours >= 0),
    actual_hours        DECIMAL(6, 2)
        CHECK (actual_hours IS NULL OR actual_hours >= 0),
    planned_start_at    TIMESTAMP,
    started_at          TIMESTAMP,
    completed_at        TIMESTAMP,
    notes               TEXT,

    CONSTRAINT uq_work_order_tasks_sequence
        UNIQUE (work_order_id, sequence_number),

    CONSTRAINT chk_work_order_tasks_started_after_planned
        CHECK (started_at IS NULL OR planned_start_at IS NULL OR started_at >= planned_start_at),

    CONSTRAINT chk_work_order_tasks_completed_after_started
        CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
);


CREATE TABLE usage_logs (
    usage_log_id            INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id                INTEGER         NOT NULL REFERENCES assets(asset_id),
    usage_date              DATE            NOT NULL,

    flight_hours            DECIMAL(6, 2)
        CHECK (flight_hours IS NULL OR flight_hours >= 0),

    -- I contatori seguenti sono NOT NULL con DEFAULT 0 (deviazione intenzionale dal modello
    -- logico che li prevedeva nullable). La scelta semplifica le aggregazioni analitiche
    -- evitando la gestione di NULL nelle somme e nei conteggi.
    missions_count          INTEGER         NOT NULL DEFAULT 0
        CHECK (missions_count >= 0),
    critical_missions_count INTEGER         NOT NULL DEFAULT 0
        CHECK (critical_missions_count >= 0),
    operational_days        INTEGER         NOT NULL DEFAULT 0
        CHECK (operational_days >= 0),

    CONSTRAINT uq_usage_logs_asset_date
        UNIQUE (asset_id, usage_date),

    CONSTRAINT chk_usage_logs_critical_le_missions
        CHECK (critical_missions_count <= missions_count)
);


-- ============================================
-- TABELLE DI STORICO O CONFIGURAZIONE
-- ============================================

CREATE TABLE asset_components (
    asset_component_id      INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id                INTEGER         NOT NULL REFERENCES assets(asset_id),
    component_type_id       INTEGER         NOT NULL REFERENCES components_catalog(component_type_id),
    installed_serial_number VARCHAR(100),
    installed_at            TIMESTAMP       NOT NULL,
    removed_at              TIMESTAMP,
    installation_status     VARCHAR(20)     NOT NULL DEFAULT 'installed'
        CHECK (installation_status IN ('installed', 'removed')),
    position_code           VARCHAR(50),

    -- removed_at e installation_status devono essere coerenti tra loro
    CONSTRAINT chk_asset_components_status_coherence
        CHECK (
            (removed_at IS NULL     AND installation_status = 'installed') OR
            (removed_at IS NOT NULL AND installation_status = 'removed')
        ),

    CONSTRAINT chk_install_remove_dates
        CHECK (removed_at IS NULL OR removed_at > installed_at)
);


CREATE TABLE asset_base_history (
    asset_base_history_id   INTEGER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id                INTEGER         NOT NULL REFERENCES assets(asset_id),
    base_id                 INTEGER         NOT NULL REFERENCES bases(base_id),
    start_date              DATE            NOT NULL,
    end_date                DATE,
    transfer_reason         VARCHAR(255),
    is_current_flag         BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_asset_base_history_end_after_start
        CHECK (end_date IS NULL OR end_date >= start_date)
);


-- ============================================
-- TABELLE PONTE
-- ============================================

CREATE TABLE task_required_components (
    task_template_id    INTEGER         NOT NULL REFERENCES task_catalog(task_template_id),
    component_type_id   INTEGER         NOT NULL REFERENCES components_catalog(component_type_id),
    estimated_quantity  DECIMAL(6, 2)   NOT NULL DEFAULT 1
        CHECK (estimated_quantity > 0),

    PRIMARY KEY (task_template_id, component_type_id)
);


CREATE TABLE work_order_task_required_components (
    work_order_task_id  INTEGER         NOT NULL REFERENCES work_order_tasks(work_order_task_id),
    component_type_id   INTEGER         NOT NULL REFERENCES components_catalog(component_type_id),
    estimated_quantity  DECIMAL(6, 2)
        CHECK (estimated_quantity IS NULL OR estimated_quantity >= 0),
    actual_quantity     DECIMAL(6, 2)
        CHECK (actual_quantity IS NULL OR actual_quantity >= 0),

    PRIMARY KEY (work_order_task_id, component_type_id)
);


-- ============================================
-- INDICI
-- ============================================

-- ---- Indici base (integrità referenziale e lookup per FK) ----

CREATE INDEX idx_assets_base
    ON assets(current_base_id);

CREATE INDEX idx_teams_base
    ON teams(base_id);

CREATE INDEX idx_anomalies_asset
    ON anomalies(asset_id);

CREATE INDEX idx_work_orders_anomaly
    ON work_orders(anomaly_id);

CREATE INDEX idx_work_orders_team
    ON work_orders(team_id);

CREATE INDEX idx_work_order_tasks_wo
    ON work_order_tasks(work_order_id);

CREATE INDEX idx_asset_components_asset
    ON asset_components(asset_id);

CREATE INDEX idx_asset_base_history_asset
    ON asset_base_history(asset_id);

-- ---- Indici temporali (essenziali per KPI analitici) ----
-- Le colonne di apertura, chiusura e scadenza sono al centro di ogni calcolo
-- su lead time, MTTR, backlog e rispetto degli SLA.

CREATE INDEX idx_work_orders_opened_at
    ON work_orders(opened_at);

CREATE INDEX idx_work_orders_completed_at
    ON work_orders(completed_at);

CREATE INDEX idx_work_orders_due_at
    ON work_orders(due_at);

CREATE INDEX idx_anomalies_detected_at
    ON anomalies(detected_at);

-- ---- Indici su stato (filtraggio per backlog e monitoraggio) ----

CREATE INDEX idx_anomalies_status
    ON anomalies(anomaly_status);

CREATE INDEX idx_work_orders_status
    ON work_orders(work_order_status);

-- ---- Indici compositi (pattern analitici frequenti) ----
-- "Work order aperti in un periodo per una base" richiede status + data + join su team.
-- "Anomalie recenti per severità" richiede status + detected_at.

CREATE INDEX idx_work_orders_status_opened
    ON work_orders(work_order_status, opened_at);

CREATE INDEX idx_anomalies_status_detected
    ON anomalies(anomaly_status, detected_at);

-- ---- Indice parziale per backlog attivo ----
-- Il backlog è la query più ripetuta del progetto. Limitare la scansione
-- ai soli work order non chiusi riduce drasticamente il volume letto.

CREATE INDEX idx_work_orders_open_backlog
    ON work_orders(opened_at, team_id)
    WHERE work_order_status IN ('open', 'assigned', 'in_progress', 'pending_parts');

-- ---- Indici temporali usage_logs ----
-- La UNIQUE (asset_id, usage_date) copre già le query filtrate per asset_id.
-- idx_usage_logs_asset (presente in v1) è quindi ridondante ed è stato rimosso.

CREATE INDEX idx_usage_logs_date
    ON usage_logs(usage_date);

-- ---- Indice parziale per configurazione corrente degli asset ----
-- Le query sulla base corrente di un asset filtrano quasi sempre is_current_flag = TRUE.

CREATE INDEX idx_asset_base_history_current
    ON asset_base_history(asset_id)
    WHERE is_current_flag = TRUE;

-- ---- Unique parziale: un solo record corrente per asset in asset_base_history ----
-- Enforza la regola di business: nessun asset può avere due assegnazioni correnti
-- contemporanee. Senza questo vincolo il dato si corrompe silenziosamente.

CREATE UNIQUE INDEX uq_asset_base_history_one_current
    ON asset_base_history(asset_id)
    WHERE is_current_flag = TRUE;


-- ============================================
-- COMMENTI
-- ============================================

COMMENT ON TABLE bases IS 'Anagrafica delle basi operative o manutentive';
COMMENT ON TABLE assets IS 'Anagrafica della flotta o degli asset monitorati';
COMMENT ON TABLE components_catalog IS 'Catalogo dei tipi di componente';
COMMENT ON TABLE teams IS 'Anagrafica dei team manutentivi';
COMMENT ON TABLE task_catalog IS 'Catalogo delle attività standard di manutenzione';
COMMENT ON TABLE anomalies IS 'Evento tecnico rilevato su un asset; origine del processo manutentivo';
COMMENT ON TABLE work_orders IS 'Ordine di lavoro aperto dall anomalia; unità centrale per SLA e backlog';
COMMENT ON TABLE work_order_tasks IS 'Azioni operative concrete del work order; permette confronto stimato vs reale';
COMMENT ON TABLE usage_logs IS 'Registro temporale di utilizzo dell asset; collega intensità d uso e carico manutentivo';
COMMENT ON TABLE asset_components IS 'Storico componenti installati sui singoli asset';
COMMENT ON TABLE asset_base_history IS 'Storico assegnazioni dell asset alle basi; permette analisi di mobilità e carico storico';
COMMENT ON TABLE task_required_components IS 'Componenti tipicamente richiesti per una task standard (catalogo teorico)';
COMMENT ON TABLE work_order_task_required_components IS 'Componenti stimati e realmente usati per una task concreta';

COMMENT ON COLUMN work_orders.team_id IS 'Nullable: il team viene assegnato quando il WO transisce da open ad assigned. La coerenza con assigned_at è garantita dal CHECK chk_work_orders_team_assignment_coherence';
COMMENT ON COLUMN asset_base_history.is_current_flag IS 'TRUE per la riga corrente. Unicità garantita dall indice parziale uq_asset_base_history_one_current';
COMMENT ON COLUMN bases.longitude IS 'DECIMAL(11,7): 3 cifre intere per coprire [-180, 180], 7 decimali per precisione ~1 cm';