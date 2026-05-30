-- =============================================================================
-- DCM schemas — the only thing DCM owns in this demo.
-- dbt owns all tables (staging, HOL-shape, marts).
--
-- ${TARGET_DB} is substituted by scripts/deploy.py at deploy time. If you're
-- running `snow dcm deploy` directly (not via deploy.py), set the env var:
-- export TARGET_DB=PAWCORE_ANALYTICS
-- =============================================================================

DEFINE SCHEMA ${TARGET_DB}.RAW
    COMMENT = 'Landing zone — COPY INTO from PawCore HOL GitHub CSVs';

DEFINE SCHEMA ${TARGET_DB}.STAGING
    COMMENT = 'dbt staging layer — typed, cleaned views over RAW';

DEFINE SCHEMA ${TARGET_DB}.DEVICE_DATA
    COMMENT = 'HOL-compatible: device telemetry (agent semantic view reads here)';

DEFINE SCHEMA ${TARGET_DB}.MANUFACTURING
    COMMENT = 'HOL-compatible: manufacturing quality logs';

DEFINE SCHEMA ${TARGET_DB}.SUPPORT
    COMMENT = 'HOL-compatible: customer reviews + slack messages';

DEFINE SCHEMA ${TARGET_DB}.ANALYTICS
    COMMENT = 'dbt marts — lot quality, regional impact, battery × moisture';

DEFINE SCHEMA ${TARGET_DB}.SEMANTIC
    COMMENT = 'Reserved for follow-on Cortex AI HOL — semantic view + agent';

DEFINE SCHEMA ${TARGET_DB}.DBT_PROD
    COMMENT = 'Default target for dbt (individual models override via +schema)';
