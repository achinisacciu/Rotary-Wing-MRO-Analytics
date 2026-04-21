# Modello logico — Maintenance Operations Analytics

## Scopo del documento
Questo documento descrive il **modello logico** del progetto di analytics sul processo manutentivo di una flotta aerospace. Il focus è sulla traduzione delle entità concettuali in **tabelle relazionali**, con indicazione di chiavi primarie, chiavi esterne, vincoli e ruolo analitico di ciascuna tabella, mantenendo il perimetro su maintenance support, work order management, asset supportability e disponibilità operativa.

Il modello è pensato per supportare KPI come backlog, tempi di presa in carico, lead time di chiusura, fuori SLA, workload per team e collegamento tra utilizzo asset e carico manutentivo.

## Principi di progettazione logica
| Principio | Significato |
|---|---|
| Normalizzazione controllata | Separare anagrafiche, eventi, processo e storico per evitare ridondanza inutile |
| Chiarezza delle responsabilità | Il work order è assegnato a un solo team nella v1 |
| Temporalità esplicita | Uso, spostamenti e installazioni sono storicizzati |
| Distinzione standard vs reale | Cataloghi separati dalle istanze operative |
| Orientamento analitico | Il modello è costruito per interrogazioni e dashboard, non per ERP completo |

## Elenco tabelle
### Tabelle anagrafiche
| Tabella | Ruolo |
|---|---|
| `bases` | Anagrafica delle basi operative o manutentive |
| `assets` | Anagrafica della flotta o degli asset monitorati |
| `components_catalog` | Catalogo dei tipi di componente |
| `teams` | Anagrafica dei team manutentivi |
| `task_catalog` | Catalogo delle attività standard di manutenzione |

### Tabelle evento e processo
| Tabella | Ruolo |
|---|---|
| `anomalies` | Evento tecnico rilevato su un asset |
| `work_orders` | Ordine di lavoro aperto dall'anomalia |
| `work_order_tasks` | Azioni operative concrete del work order |
| `usage_logs` | Registro temporale di utilizzo dell'asset |

### Tabelle di storico o configurazione
| Tabella | Ruolo |
|---|---|
| `asset_components` | Storico componenti installati sui singoli asset |
| `asset_base_history` | Storico assegnazioni dell'asset alle basi |

### Tabelle ponte
| Tabella | Ruolo |
|---|---|
| `task_required_components` | Componenti tipicamente richiesti per una task standard |
| `work_order_task_required_components` | Componenti stimati o realmente richiesti per una task concreta, opzionale in v1 |

## Schema delle tabelle

## `bases`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `base_id` | integer | PK | No | Identificativo univoco della base |
| `base_code` | varchar | UK | No | Codice univoco della base |
| `base_name` | varchar |  | No | Nome descrittivo |
| `address` | varchar |  | Sì | Indirizzo |
| `city` | varchar |  | Sì | Città |
| `region` | varchar |  | Sì | Regione o area |
| `country` | varchar |  | Sì | Nazione |
| `latitude` | decimal |  | Sì | Coordinata geografica |
| `longitude` | decimal |  | Sì | Coordinata geografica |
| `maintenance_level` | varchar |  | Sì | Livello di manutenzione disponibile |
| `status` | varchar |  | No | Stato attivo/inattivo |

## `assets`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `asset_id` | integer | PK | No | Identificativo asset |
| `asset_code` | varchar | UK | No | Codice interno asset |
| `serial_number` | varchar | UK | No | Numero seriale univoco |
| `model` | varchar |  | No | Modello del mezzo |
| `manufacturer` | varchar |  | Sì | Produttore |
| `manufacture_year` | integer |  | Sì | Anno di fabbricazione |
| `entry_into_service_date` | date |  | Sì | Data entrata in servizio |
| `current_base_id` | integer | FK | No | Riferimento a `bases.base_id` |
| `asset_status` | varchar |  | No | Stato operativo |
| `mission_role` | varchar |  | Sì | Ruolo missione o classe di impiego |

## `components_catalog`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `component_type_id` | integer | PK | No | Identificativo tipo componente |
| `component_code` | varchar | UK | No | Codice catalogo |
| `component_name` | varchar |  | No | Nome del componente |
| `component_category` | varchar |  | No | Categoria tecnica |
| `criticality_level` | varchar |  | Sì | Livello di criticità |
| `vendor` | varchar |  | Sì | Fornitore |
| `standard_replacement_hours` | decimal |  | Sì | Tempo standard di sostituzione |
| `is_repairable` | boolean |  | Sì | Indica se il componente è riparabile |

## `teams`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `team_id` | integer | PK | No | Identificativo team |
| `team_code` | varchar | UK | No | Codice team |
| `team_name` | varchar |  | No | Nome del team |
| `base_id` | integer | FK | No | Base di appartenenza |
| `specialization` | varchar |  | Sì | Specializzazione principale |
| `capacity_level` | varchar |  | Sì | Capacità o seniority sintetica |
| `status` | varchar |  | No | Stato attivo/inattivo |

## `task_catalog`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `task_template_id` | integer | PK | No | Identificativo task standard |
| `task_code` | varchar | UK | No | Codice task |
| `task_name` | varchar |  | No | Nome attività |
| `task_category` | varchar |  | Sì | Categoria attività |
| `standard_duration_hours` | decimal |  | No | Durata standard |
| `complexity_level` | varchar |  | Sì | Complessità prevista |
| `requires_shutdown_flag` | boolean |  | Sì | Indica se richiede fermo asset |
| `description` | text |  | Sì | Descrizione sintetica |

## `anomalies`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `anomaly_id` | integer | PK | No | Identificativo anomalia |
| `anomaly_code` | varchar | UK | No | Codice anomalia |
| `asset_id` | integer | FK | No | Asset coinvolto |
| `detected_at` | datetime |  | No | Momento di rilevazione |
| `reported_at` | datetime |  | Sì | Momento di registrazione |
| `severity_level` | varchar |  | No | Gravità tecnica |
| `priority_level` | varchar |  | No | Urgenza operativa |
| `anomaly_status` | varchar |  | No | Stato anomalia |
| `affected_component_type_id` | integer | FK | Sì | Tipo componente coinvolto |
| `symptom_description` | text |  | Sì | Descrizione del sintomo |
| `mission_impact_level` | varchar |  | Sì | Impatto sull'operatività |

## `work_orders`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `work_order_id` | integer | PK | No | Identificativo work order |
| `work_order_code` | varchar | UK | No | Codice work order |
| `anomaly_id` | integer | FK, UNIQUE | No | Una anomalia genera un solo work order |
| `team_id` | integer | FK | No | Team assegnato |
| `opened_at` | datetime |  | No | Apertura work order |
| `assigned_at` | datetime |  | Sì | Assegnazione al team |
| `due_at` | datetime |  | Sì | Scadenza target |
| `started_at` | datetime |  | Sì | Inizio lavorazioni |
| `completed_at` | datetime |  | Sì | Fine lavorazioni |
| `closed_at` | datetime |  | Sì | Chiusura amministrativa |
| `work_order_status` | varchar |  | No | Stato del work order |
| `sla_hours` | decimal |  | Sì | Tempo target in ore |
| `estimated_total_hours` | decimal |  | Sì | Totale ore stimate |
| `actual_total_hours` | decimal |  | Sì | Totale ore effettive |

## `work_order_tasks`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `work_order_task_id` | integer | PK | No | Identificativo task concreta |
| `work_order_id` | integer | FK | No | Work order di appartenenza |
| `task_template_id` | integer | FK | No | Task standard di origine |
| `sequence_number` | integer |  | No | Ordine logico nel work order |
| `task_status` | varchar |  | No | Stato task |
| `estimated_hours` | decimal |  | Sì | Tempo previsto |
| `actual_hours` | decimal |  | Sì | Tempo effettivo |
| `planned_start_at` | datetime |  | Sì | Inizio pianificato |
| `started_at` | datetime |  | Sì | Inizio reale |
| `completed_at` | datetime |  | Sì | Fine reale |
| `notes` | text |  | Sì | Note operative |

## `usage_logs`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `usage_log_id` | integer | PK | No | Identificativo del log |
| `asset_id` | integer | FK | No | Asset a cui si riferisce |
| `usage_date` | date |  | No | Giorno di osservazione |
| `flight_hours` | decimal |  | Sì | Ore di volo giornaliere |
| `missions_count` | integer |  | Sì | Numero missioni |
| `critical_missions_count` | integer |  | Sì | Missioni critiche |
| `operational_days` | integer |  | Sì | Giorni operativi nel periodo |

## `asset_components`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `asset_component_id` | integer | PK | No | Identificativo installazione |
| `asset_id` | integer | FK | No | Asset su cui è installato il componente |
| `component_type_id` | integer | FK | No | Tipo componente |
| `installed_serial_number` | varchar |  | Sì | Seriale del componente installato |
| `installed_at` | datetime |  | No | Data installazione |
| `removed_at` | datetime |  | Sì | Data rimozione |
| `installation_status` | varchar |  | No | Stato installazione |
| `position_code` | varchar |  | Sì | Posizione o slot tecnico |

## `asset_base_history`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `asset_base_history_id` | integer | PK | No | Identificativo storico base |
| `asset_id` | integer | FK | No | Asset movimentato |
| `base_id` | integer | FK | No | Base di destinazione o assegnazione |
| `start_date` | date |  | No | Inizio permanenza |
| `end_date` | date |  | Sì | Fine permanenza |
| `transfer_reason` | varchar |  | Sì | Motivo trasferimento |
| `is_current_flag` | boolean |  | No | Indica la riga corrente |

## Tabelle ponte

## `task_required_components`
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `task_template_id` | integer | PK, FK | No | Riferimento a `task_catalog` |
| `component_type_id` | integer | PK, FK | No | Riferimento a `components_catalog` |
| `estimated_quantity` | decimal |  | No | Quantità standard richiesta |

**Chiave primaria composta**: (`task_template_id`, `component_type_id`)

## `work_order_task_required_components` *(opzionale)*
| Campo | Tipo logico | Chiave | Null | Note |
|---|---|---|---|---|
| `work_order_task_id` | integer | PK, FK | No | Riferimento a `work_order_tasks` |
| `component_type_id` | integer | PK, FK | No | Riferimento a `components_catalog` |
| `estimated_quantity` | decimal |  | Sì | Quantità stimata |
| `actual_quantity` | decimal |  | Sì | Quantità realmente usata |

**Chiave primaria composta**: (`work_order_task_id`, `component_type_id`)

## Relazioni logiche principali
| Da tabella | A tabella | Tipo relazione | Implementazione |
|---|---|---|---|
| `assets` | `bases` | N a 1 | `assets.current_base_id` |
| `teams` | `bases` | N a 1 | `teams.base_id` |
| `anomalies` | `assets` | N a 1 | `anomalies.asset_id` |
| `anomalies` | `components_catalog` | N a 1 | `anomalies.affected_component_type_id` |
| `work_orders` | `anomalies` | 1 a 1 | `work_orders.anomaly_id` con vincolo UNIQUE |
| `work_orders` | `teams` | N a 1 | `work_orders.team_id` |
| `work_order_tasks` | `work_orders` | N a 1 | `work_order_tasks.work_order_id` |
| `work_order_tasks` | `task_catalog` | N a 1 | `work_order_tasks.task_template_id` |
| `usage_logs` | `assets` | N a 1 | `usage_logs.asset_id` |
| `asset_components` | `assets` | N a 1 | `asset_components.asset_id` |
| `asset_components` | `components_catalog` | N a 1 | `asset_components.component_type_id` |
| `asset_base_history` | `assets` | N a 1 | `asset_base_history.asset_id` |
| `asset_base_history` | `bases` | N a 1 | `asset_base_history.base_id` |
| `task_required_components` | `task_catalog` | N a 1 | `task_required_components.task_template_id` |
| `task_required_components` | `components_catalog` | N a 1 | `task_required_components.component_type_id` |

## Vincoli di business da tradurre in vincoli logici
| Regola | Traduzione logica |
|---|---|
| Ogni anomalia genera un solo work order | `work_orders.anomaly_id` obbligatorio e univoco |
| Ogni work order ha un team assegnato | `work_orders.team_id` NOT NULL |
| Ogni task concreta appartiene a un work order | `work_order_tasks.work_order_id` NOT NULL |
| Ogni task concreta deriva da una task standard | `work_order_tasks.task_template_id` NOT NULL |
| Un asset ha una sola base corrente | `assets.current_base_id` NOT NULL |
| Lo storico basi non deve avere due righe correnti contemporanee per lo stesso asset | controllo logico o vincolo applicativo su `asset_base_history` |
| Le date di rimozione componente devono seguire le date di installazione | check logico su `asset_components` |
| Le date di chiusura devono seguire l'apertura del work order | check logico su `work_orders` |

## Versione minima consigliata
Per la prima implementazione del progetto, il set minimo ma già robusto di tabelle è il seguente:

| Priorità | Tabelle |
|---|---|
| Core obbligatorie | `bases`, `assets`, `components_catalog`, `teams`, `task_catalog`, `anomalies`, `work_orders`, `work_order_tasks` |
| Fortemente consigliate | `usage_logs`, `asset_components`, `asset_base_history` |
| Seconda iterazione | `task_required_components`, `work_order_task_required_components` |

## Cose da non aggiungere ancora
| Tabella o area | Motivo |
|---|---|
| `personnel` | Aumenta molto la complessità organizzativa |
| `shifts` | Introduce pianificazione workforce prematura |
| `inventory_stock` | Sposta il focus su logistica avanzata |
| `purchase_orders` | Porta verso procurement |
| `missions_detail` | Porta verso flight operations più che manutenzione |
| `cost_accounting` | Richiede un layer economico non necessario in v1 |

## Uso pratico del documento
Questo documento può essere usato per:

- costruire il diagramma ER;
- scrivere gli script SQL di creazione tabelle;
- definire i CSV iniziali;
- progettare il dizionario dati;
- mappare le future relazioni nel modello Power BI.