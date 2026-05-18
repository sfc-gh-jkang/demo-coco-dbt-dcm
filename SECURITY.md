# Security Policy

## Reporting a Vulnerability

Please report security issues **privately** to john.kang@snowflake.com.

Do **not** open public GitHub issues for security concerns.

You should expect an acknowledgement within 5 business days. We'll work with you on a coordinated disclosure timeline once the issue is triaged.

## Scope

This is a Snowflake hands-on-lab demo repository. The code in this repo is intended to be deployed into a **fresh Snowflake trial account** owned by the person running the lab — it is not a production system, and no third-party data or credentials are stored here.

## Out of scope

- Findings against the upstream PawCore HOL data set ([calebaalexander/HandsOnLabs](https://github.com/calebaalexander/HandsOnLabs)) — please report those upstream.
- Findings against vendored dbt packages (`dbt/dbt_packages/`) — please report those to the package maintainers.
- Findings against Snowflake itself — please use [Snowflake's responsible disclosure program](https://www.snowflake.com/legal/security-and-trust/).
