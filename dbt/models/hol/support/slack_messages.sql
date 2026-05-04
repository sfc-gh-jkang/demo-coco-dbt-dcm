{{
    config(
        materialized='table',
        alias='SLACK_MESSAGES'
    )
}}

-- HOL-compatible: PAWCORE_ANALYTICS.SUPPORT.SLACK_MESSAGES
-- Matches upstream HOL pawcore_setup.sql line 280-286.
-- Phase 1 compat check expects columns: TEXT, SLACK_CHANNEL, THREAD_ID.

SELECT
    message_id,
    slack_channel,
    user_name,
    text,
    thread_id
FROM {{ ref('stg_slack_messages') }}
