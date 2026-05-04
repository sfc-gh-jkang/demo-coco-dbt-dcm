{{ config(materialized='view') }}

-- stg_slack_messages — typed passthrough of RAW.SLACK_MESSAGES.

SELECT
    CAST(message_id AS VARCHAR(50))         AS message_id,
    CAST(slack_channel AS VARCHAR(50))      AS slack_channel,
    CAST(user_name AS VARCHAR(100))         AS user_name,
    CAST(text AS TEXT)                      AS text,
    CAST(thread_id AS VARCHAR(50))          AS thread_id
FROM {{ source('raw', 'slack_messages') }}
WHERE message_id IS NOT NULL
