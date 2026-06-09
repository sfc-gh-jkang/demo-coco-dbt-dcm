# Attendee Quickstart

Pre-work for the **Prompt to Pipeline** Hands On Lab.

## Before the webinar (10 minutes)

### 1. Get a Snowflake trial account

If you don't have one: https://signup.snowflake.com/ → choose **Standard** edition, any cloud/region. You'll get ACCOUNTADMIN by default.

### 2. Install Snowflake CLI

```bash
# macOS
brew install snowflake-cli

# Other: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation
```

### 3. Configure your connection

```bash
snow connection add \
    --connection-name trial \
    --account <your-account-identifier> \
    --user <your-username> \
    --authenticator externalbrowser

snow connection test --connection trial
```

### 4. Install Cortex Code

Follow: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code

Verify:

```bash
cortex --version
cortex connections set trial
```

### 5. Clone the demo repo

```bash
git clone https://github.com/sfc-gh-jkang/demo-coco-dbt-dcm.git
cd demo-coco-dbt-dcm
```

## 5-minute pre-flight (day-of)

Open a terminal in the repo root:

```bash
# Confirm CLI is working
snow sql -q "SELECT CURRENT_ACCOUNT(), CURRENT_USER(), CURRENT_ROLE()" -c trial

# Confirm Cortex Code is wired up
cortex connections list
```

If both work, you're ready. If either fails, ping the facilitator in the webinar chat.

## During the webinar

Follow along. You'll be prompted to run specific commands at key points. If you fall behind, don't stress — the recording goes out after.

## After the webinar

1. Verify the pipeline:
   ```bash
   snow sql -q "SHOW TABLES IN DATABASE PAWCORE_ANALYTICS" -c trial
   ```
2. Run the follow-on [Cortex AI + Snowflake Intelligence HOL](https://github.com/sfc-gh-calexander/HandsOnLabs/tree/main/1-Cortex-AI-Snowflake-Intelligence) to attach a Cortex Agent on top.
3. Clean up when done:
   ```bash
   snow sql -f teardown.sql -c trial
   ```
