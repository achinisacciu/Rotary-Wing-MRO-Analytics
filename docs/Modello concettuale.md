# Modello concettuale - Maintenance Operations Analytics

## Scopo del documento

Questo documento descrive il **modello concettuale** del progetto di analytics sul processo manutentivo di una flotta aerospace.
L’obiettivo è rappresentare in modo chiaro **le entità principali del dominio**, le loro **relazioni** e le **regole di business** fondamentali, senza entrare ancora nel dettaglio tecnico di chiavi, tipi dato o struttura SQL.

Il focus del progetto resta su:

- asset;
- basi operative;
- anomalie;
- work order;
- task operative;
- componenti;
- team;
- utilizzo operativo;
- storicizzazione dei movimenti.


## Perimetro del modello

Il modello vuole rappresentare il seguente flusso logico:

**asset -> anomalia -> work order -> task operative -> completamento del lavoro**

A questo flusso si affiancano tre dimensioni di contesto:

- la **base operativa** in cui l’asset si trova;
- i **componenti** installati e quelli coinvolti nel lavoro;
- il **team manutentivo** responsabile del work order.


## Principi di modellazione

| Principio | Significato |
| :-- | :-- |
| Focus sul processo | Il modello non descrive tutta l’azienda, ma solo il processo manutentivo |
| Separazione dei livelli | Oggetti, eventi e processo vengono distinti |
| Realismo controllato | Il modello è credibile ma non eccessivamente pesante |
| Evolvibilità | Gli attributi possono essere ampliati in versioni successive |
| Orientamento analitico | Ogni entità deve servire a produrre KPI, insight o dashboard |

## Blocchi concettuali

| Blocco | Contenuto |
| :-- | :-- |
| Struttura | Base, Asset, Team, Component Type, Task Template |
| Evento | Anomaly, Usage Log |
| Processo | Work Order, Work Order Task |
| Storia / configurazione | Asset Component Installation, Asset Base Assignment |

## Lista entità concettuali

## Entità principali

| Entità | Descrizione | Ruolo nel dominio |
| :-- | :-- | :-- |
| Base | Sede operativa o manutentiva | Contiene o ospita asset e capacità operative |
| Asset | Mezzo tecnico da monitorare | Oggetto centrale del processo manutentivo |
| Component Type | Tipo di componente tecnico | Catalogo dei componenti riusabili su più asset |
| Team | Squadra manutentiva | Responsabile dell’esecuzione dei work order |
| Task Template | Catalogo delle attività standard | Definisce le azioni tipiche e i tempi standard |
| Anomaly | Problema tecnico rilevato | Evento che apre il processo manutentivo |
| Work Order | Ordine di lavoro | Contiene il lavoro da eseguire per risolvere l’anomalia |
| Work Order Task | Attività concreta da eseguire | Istanza operativa di una task standard |
| Usage Log | Registro d’uso dell’asset | Misura utilizzo operativo nel tempo |
| Asset Component Installation | Configurazione componenti installati | Collega asset e componenti nel tempo |
| Asset Base Assignment | Storico degli spostamenti tra basi | Traccia i movimenti dell’asset tra sedi |

## Descrizione delle entità

### Base

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Sede in cui un asset può essere collocato o gestito |
| Funzione | Contestualizza posizione, carico operativo e performance |
| Perché serve | Permette confronti tra sedi, backlog locali e distribuzione della flotta |

### Asset

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Mezzo fisico da monitorare, ad esempio un elicottero |
| Funzione | È il centro fisico del dominio |
| Perché serve | Tutte le anomalie, i componenti installati e i log d’uso fanno riferimento all’asset |

### Component Type

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Tipo di componente appartenente a un catalogo tecnico |
| Funzione | Standardizza i componenti coinvolti in anomalie e task |
| Perché serve | Consente analisi aggregate su categorie e criticità componenti |

### Team

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Squadra di manutenzione responsabile di un insieme di work order |
| Funzione | Rappresenta la responsabilità operativa |
| Perché serve | Permette di misurare carico, backlog e tempi per team |

### Task Template

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Attività standard di catalogo |
| Funzione | Definisce il tipo di lavoro e il tempo standard previsto |
| Perché serve | Separa il lavoro teorico da quello effettivamente svolto |

### Anomaly

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Problema tecnico rilevato su un asset |
| Funzione | Innesca il work order |
| Perché serve | È l’origine del processo manutentivo |

### Work Order

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Ordine di lavoro aperto per gestire una anomalia |
| Funzione | Contiene il perimetro operativo del lavoro |
| Perché serve | È l’unità centrale per SLA, backlog, lead time e assegnazione del team |

### Work Order Task

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Attività concreta appartenente a un work order |
| Funzione | Traduce il lavoro in azioni operative misurabili |
| Perché serve | Permette di confrontare tempi stimati e tempi reali |

### Usage Log

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Rilevazione temporale dell’utilizzo dell’asset |
| Funzione | Registra ore di volo, missioni o giorni operativi |
| Perché serve | Collega intensità d’uso e comportamento manutentivo |

### Asset Component Installation

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Relazione storicizzata tra asset e componenti installati |
| Funzione | Descrive quali componenti risultano montati nel tempo |
| Perché serve | Separa il catalogo componenti dalla configurazione reale del mezzo |

### Asset Base Assignment

| Aspetto | Contenuto |
| :-- | :-- |
| Definizione | Relazione storicizzata tra asset e base |
| Funzione | Registra i trasferimenti tra sedi |
| Perché serve | Permette analisi storiche su presenza, carico e mobilità della flotta |

## Relazioni concettuali

## Relazioni principali

| Relazione | Cardinalità | Significato |
| :-- | :-- | :-- |
| Base -> Asset | 1 a N | Una base può ospitare molti asset |
| Asset -> Anomaly | 1 a N | Un asset può generare molte anomalie |
| Anomaly -> Work Order | 1 a 1 | Ogni anomalia genera sempre un solo work order |
| Team -> Work Order | 1 a N | Un team può gestire molti work order |
| Work Order -> Work Order Task | 1 a N | Un work order contiene una o più task |
| Task Template -> Work Order Task | 1 a N | Una task standard può essere riusata in molti work order |
| Asset -> Usage Log | 1 a N | Un asset può avere molte registrazioni d’uso |
| Asset -> Asset Component Installation | 1 a N | Un asset può avere molti componenti installati nel tempo |
| Component Type -> Asset Component Installation | 1 a N | Un tipo componente può essere installato su molti asset |
| Asset -> Asset Base Assignment | 1 a N | Un asset può essere assegnato a più basi nel tempo |

## Relazioni molti-a-molti implicite

| Relazione concettuale | Come viene risolta | Significato |
| :-- | :-- | :-- |
| Asset <-> Component Type | Tramite Asset Component Installation | Un asset ha più componenti e un tipo componente può comparire su più asset |
| Task Template <-> Component Type | Tramite una relazione dedicata futura | Una task può richiedere più componenti e un componente può servire in più task |

## Regole di business concettuali

| Regola | Significato |
| :-- | :-- |
| Ogni anomalia appartiene a un solo asset | Un problema tecnico nasce sempre su un singolo mezzo |
| Ogni anomalia genera un solo work order | Il processo parte sempre con una presa in carico formale |
| Ogni work order è assegnato a un solo team | La responsabilità operativa è chiara |
| Ogni work order contiene almeno una task | Il lavoro deve essere scomposto in azioni operative |
| Le task reali derivano da un catalogo standard | Esiste distinzione tra attività teorica e attività eseguita |
| I componenti esistono come catalogo e come installazione | Si separa standard tecnico da configurazione reale |
| Gli spostamenti delle basi vanno storicizzati | La posizione dell’asset può cambiare nel tempo |
| L’utilizzo dell’asset è temporale | Ore di volo e missioni non sono attributi statici |

## Confini del modello

## Cose incluse

| Incluso | Motivazione |
| :-- | :-- |
| Basi operative | Servono per confronti organizzativi e geografici |
| Asset | Sono il centro del modello |
| Anomalie | Attivano il processo |
| Work order | Permettono analisi di backlog e SLA |
| Task | Rendono misurabile il lavoro reale |
| Team | Rendono chiara la responsabilità operativa |
| Componenti | Servono per leggere criticità tecniche |
| Usage log | Collega utilizzo e manutenzione |
| Storico basi | Aggiunge realismo senza eccessivo costo |
| Configurazione componenti | Permette una lettura più matura degli asset |

## Cose escluse nella v1

| Escluso | Perché |
| :-- | :-- |
| Piloti | Portano il modello verso operations di volo e non manutenzione |
| Personale completo | Aumenta troppo la complessità iniziale |
| Turni | Meglio inserirli in una fase successiva |
| Magazzino reale | Sposta il focus verso supply chain avanzata |
| Costi completi | Possono venire dopo, quando il modello è stabile |
| Mission planning dettagliato | Rischia di far deragliare il progetto |
| Workflow applicativo completo | Il progetto è analitico, non un software gestionale full-stack |

## Domande a cui il modello deve rispondere

| Area | Domande |
| :-- | :-- |
| Processo | Dove si accumulano i ritardi? |
| SLA | Quali work order sforano i tempi target? |
| Carico operativo | Quali team hanno più backlog? |
| Affidabilità operativa | Quali asset generano più anomalie? |
| Configurazione tecnica | Quali componenti compaiono più spesso nei casi critici? |
| Utilizzo | Un maggior uso dell’asset è associato a più lavoro manutentivo? |
| Basi | Quali basi mostrano le performance peggiori? |

## Struttura concettuale finale

| Livello | Entità |
| :-- | :-- |
| Struttura | Base, Asset, Component Type, Team, Task Template |
| Evento | Anomaly, Usage Log |
| Processo | Work Order, Work Order Task |
| Storia / configurazione | Asset Component Installation, Asset Base Assignment |

## Versione consigliata

Questa versione del modello concettuale è abbastanza ricca da:

- essere credibile;
- supportare KPI di processo;
- generare un modello logico solido;
- non diventare ingestibile.