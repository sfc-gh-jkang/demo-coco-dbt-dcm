# Architecture

> Pre-rendered PNGs of both diagrams live in [`docs/images/`](images/) — useful for GitHub previews, slides, and tools without a Mermaid renderer.

## Data flow

![Data flow](images/architecture_data_flow.png)

```mermaid
flowchart LR
    subgraph External["Local data/ folder"]
        CSV[CSVs in data/*]
    end

    subgraph Snowflake["PAWCORE_ANALYTICS"]
        direction TB
        subgraph RAW["RAW (DCM-managed schema)"]
            R1[TELEMETRY]
            R2[QUALITY_LOGS]
            R3[CUSTOMER_REVIEWS]
            R4[SLACK_MESSAGES]
        end

        subgraph STG["STAGING (dbt views)"]
            S1[stg_telemetry]
            S2[stg_quality_logs]
            S3[stg_customer_reviews]
            S4[stg_slack_messages]
        end

        subgraph HOL["HOL-compat tables (dbt)"]
            H1[DEVICE_DATA.TELEMETRY]
            H2[MANUFACTURING.QUALITY_LOGS]
            H3[SUPPORT.CUSTOMER_REVIEWS]
            H4[SUPPORT.SLACK_MESSAGES]
        end

        subgraph MART["ANALYTICS marts (dbt)"]
            M1[mart_lot_quality_correlation]
            M2[mart_regional_customer_impact]
            M3[mart_battery_moisture_correlation]
        end

        subgraph AI["Snowflake Intelligence (deploy.py steps 6-7)"]
            SV[SEMANTIC.PAWCORE_ANALYSIS<br/>semantic view]
            AG[SNOWFLAKE_INTELLIGENCE.PAWCORE_ASSISTANT<br/>agent]
        end
    end

    subgraph User["Attendee"]
        Q[Natural-language question]
    end

    CSV -->|COPY INTO| R1
    CSV -->|COPY INTO| R2
    CSV -->|COPY INTO| R3
    CSV -->|COPY INTO| R4

    R1 --> S1 --> H1
    R2 --> S2 --> H2
    R3 --> S3 --> H3
    R4 --> S4 --> H4

    S1 --> M1
    S2 --> M1
    S3 --> M2
    S1 --> M2
    S1 --> M3
    S2 --> M3

    H1 --> SV
    H2 --> SV
    H3 --> SV
    H4 --> SV
    M1 --> SV
    M2 --> SV
    M3 --> SV
    SV --> AG
    Q --> AG
    AG -->|answer + SQL| Q
```

## Deploy flow

![Deploy flow](images/architecture_deploy_flow.png)

```mermaid
flowchart TB
    A[Step 1: bootstrap/00_bootstrap.sql<br/>DB + WH + git integration + stage] --> B
    B[Step 2: snow dcm create + deploy<br/>8 schemas] --> C
    C[Step 3: bootstrap/01_load_raw.sql<br/>CSVs → RAW tables] --> D
    D[Step 4: snowflake/create_dbt_project.sql<br/>CREATE DBT PROJECT FROM @git] --> E
    E[Step 5: snowflake/run_pipeline.sql<br/>EXECUTE DBT PROJECT args=build]
    E --> F
    F[Step 6: snowflake/create_semantic_view.sql<br/>PAWCORE_ANALYSIS semantic view]
    F --> G
    G[Step 7: snowflake/create_agent.sql<br/>PAWCORE_ASSISTANT agent]
    G --> H
    H[Ready: attendee asks questions<br/>in Snowsight AI &amp; ML]
```

Use `uv run scripts/deploy.py --stop-at raw-load` or `--stop-at build` to pause between steps during the webinar.

## Ownership split — DCM vs dbt

| Object type | Owner | Rationale |
|---|---|---|
| Database | Bootstrap SQL | DCM can't own its own parent |
| Warehouse | Bootstrap SQL | DCM can't manage warehouses |
| API integration + git repo | Bootstrap SQL | DCM can't manage these either |
| Schemas | **DCM** | Reviewable, plan-deployable infrastructure |
| Stages | Bootstrap SQL | Referenced in RAW load, must exist first |
| RAW tables | Bootstrap SQL | Loaded via COPY INTO from CSV, not dbt |
| Staging views | **dbt** | Business logic; belongs in model code |
| HOL-compat tables | **dbt** | Typed, tested, versioned analytical contract |
| Mart tables | **dbt** | Business value, tested, materialized |
| Semantic view | Bootstrap SQL (deploy.py step 6) | `PAWCORE_ANALYSIS` — AI-readable contract over marts + HOL tables |
| Intelligence agent | Bootstrap SQL (deploy.py step 7) | `PAWCORE_ASSISTANT` — Cortex Analyst tool reading the semantic view |
