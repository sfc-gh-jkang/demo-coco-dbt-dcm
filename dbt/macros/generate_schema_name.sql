{# -----------------------------------------------------------------------------
   generate_schema_name — override the default dbt behavior of prepending the
   target.schema (e.g., DBT_DEV) to every +schema config.

   Effect: +schema: DEVICE_DATA  →  lands at PAWCORE_ANALYTICS.DEVICE_DATA
   (NOT PAWCORE_ANALYTICS.DBT_DEV_DEVICE_DATA)

   This is required because the follow-on Cortex AI HOL agent semantic view
   reads from PAWCORE_ANALYTICS.DEVICE_DATA.TELEMETRY (exact FQN). The
   pipeline must land tables at that exact path.
   ----------------------------------------------------------------------------- #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
