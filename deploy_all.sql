/*==============================================================================
deploy_all.sql — PawCore / Cortex Code + dbt + DCM webinar demo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-06-03
==============================================================================*/

-- Expiration check (informational — warns but does not block deployment)
SELECT
    '2026-06-03'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-06-03'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-03'::DATE) < 0
        THEN 'EXPIRED — Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-03'::DATE) <= 7
        THEN 'EXPIRING SOON — ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-03'::DATE) || ' days remaining'
        ELSE 'ACTIVE — ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-03'::DATE) || ' days remaining'
    END AS demo_status;

-- =============================================================================
-- SQL-only orchestration (use scripts/deploy.sh for the full gated flow)
-- =============================================================================
-- Assumes `snow dcm deploy --project-dir dcm` has already run (see README.md).
-- This script chains the remaining SQL steps in order.
-- =============================================================================

!source bootstrap/00_bootstrap.sql
!source bootstrap/01_load_raw.sql
!source snowflake/create_dbt_project.sql
!source snowflake/run_pipeline.sql

-- Final status
SELECT 'DEPLOY COMPLETE' AS status, CURRENT_TIMESTAMP() AS completed_at;
