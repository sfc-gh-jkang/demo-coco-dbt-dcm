# Attendee Quickstart

Pre-work for the **Prompt to Pipeline** Hands-On Lab. Complete these steps **before** the webinar (10 minutes).

---

## 1. Get a Snowflake trial account

If you don't have one: https://signup.snowflake.com/ → choose **Standard** edition, any cloud/region. You'll get ACCOUNTADMIN by default.

---

## 2. Install tools

```bash
# uv (installs Python automatically)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Snowflake CLI
uv tool install snowflake-cli

# Verify
uv --version && snow --version
```

---

## 3. Configure your Snowflake connection

```bash
snow connection add
```

Follow the prompts. Use `externalbrowser` as the authenticator (opens your browser for login — supports SSO/MFA, no password stored).

Verify it works:
```bash
snow connection test
```

---

## 4. Install Cortex Code

Install the VS Code extension from the marketplace: search "Cortex Code".

Docs: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code

---

## 5. Clone the repo

```bash
git clone https://github.com/sfc-gh-jkang/demo-coco-dbt-dcm.git
cd demo-coco-dbt-dcm
```

---

## 6. Configure `.env`

```bash
cp .env.example .env
```

Edit `.env`:
- `SNOWFLAKE_CONNECTION` = your connection name from step 3
- `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE` = `1`

---

## That's it!

During the webinar we'll run `uv run scripts/deploy.py` together. See `README.md` for full details.
