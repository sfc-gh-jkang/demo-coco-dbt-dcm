# Exercise 3: Plug in a Snowflake Intelligence Agent

**Duration**: 10 minutes · **You'll do:** create a semantic view over your marts, wire up a Snowflake Intelligence agent, ask it 3 questions in plain English

---

## The goal

Close the loop. Your dbt pipeline produced analytical marts. A Snowflake Intelligence agent can now read those marts via a **semantic view** (the contract that tells the LLM what columns mean) and answer business questions conversationally. No more writing SQL for stakeholders.

## Why this matters

This is the "why does my team need CoCo + dbt + DCM?" answer. The pipeline isn't the end product — **the agent** is. And the agent only works because:

- DCM gave us reviewable schema infrastructure
- dbt gave us tested, documented, AI-readable tables
- CoCo gave us all of that in 50 minutes

---

## Step 1 — Create the semantic view (2 min)

The semantic view (and agent) are created by steps 6–7 of the deploy. Your initial deploy stopped at the dbt build, so run the fast semantic-layer step now:

```bash
uv run scripts/deploy.py --semantic-only
```

This substitutes the `${TARGET_DB}` / `${TARGET_WH}` placeholders in `snowflake/create_semantic_view.sql` and `create_agent.sql`, then runs both (~15s). It creates the semantic view **and** the `PAWCORE_ASSISTANT` agent (Step 2 below shows what that agent definition looks like and how to customize it).

> Don't run `snow sql -f snowflake/create_semantic_view.sql` directly — that file is a template with `${TARGET_DB}` placeholders that `snow` won't substitute, so it errors with `syntax error ... unexpected '$'`. The deploy script does the substitution for you.

Or prompt CoCo:

```
Run `uv run scripts/deploy.py --semantic-only` and tell me what it created.
Then run SHOW SEMANTIC VIEWS IN SCHEMA PAWCORE_ANALYTICS.SEMANTIC to verify.
```

**What got created:**
- `PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS` — a semantic view describing:
  - 4 HOL tables (TELEMETRY, QUALITY_LOGS, CUSTOMER_REVIEWS, SLACK_MESSAGES)
  - 3 marts (lot quality, regional customer impact, battery × moisture)
  - Column descriptions, synonyms, verified queries
  - Relationships between tables (lot_number joins, device_id joins)

**Sanity check:** The view should describe the **meaning** of each column in business terms ("rating: 1-5 stars, where 5 is excellent and 1 is poor") — this is what teaches the LLM how to answer questions correctly.

---

## Step 2 — Create the agent (3 min)

Step 1's `--semantic-only` already created `PAWCORE_ASSISTANT` (in the global `SNOWFLAKE_INTELLIGENCE.AGENTS` schema — that's where Snowsight's "AI & ML → Snowflake Intelligence" UI looks). If you want to **recreate or customize** it — to change the description, orchestration, or tools — use either option below. Otherwise skip to Step 3.

**Option A — CoCo prompt:**

```
Create a Snowflake Intelligence agent named PAWCORE_ASSISTANT in the
SNOWFLAKE_INTELLIGENCE.AGENTS schema. The agent should:

- Use the semantic view PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS as its primary tool
- Have the description: "Senior business analyst for PawCore smart pet collars. Helps investigate quality, customer, and operational issues."
- Include orchestration instructions telling it to always look at multiple perspectives (manufacturing, customer, operational)
- Focus on LOT341/EMEA as the known problematic area

Give me the full CREATE AGENT statement and then run it.
```

CoCo will generate and execute the `CREATE AGENT` SQL. (Reference: `snowflake/create_agent.sql` is exactly what the deploy ran.)

**Option B — Snowsight UI (alternative):**

1. Snowsight → **AI & ML** → **Snowflake Intelligence** → **Agents** → **+ Create Agent**
2. Name: `PAWCORE_ASSISTANT`
3. Database / Schema: `SNOWFLAKE_INTELLIGENCE` / `AGENTS` (the global discovery schema — Snowsight populates it automatically)
4. Add tool → **Cortex Analyst** → pick `<your TARGET_DATABASE>.SEMANTIC.PAWCORE_ANALYSIS`
5. Orchestration: "You are a senior business analyst for PawCore. When asked a question, look at manufacturing, customer, AND operational data. Focus on LOT341/EMEA as the known problematic area. Always explain your reasoning."
6. Save.

---

## Step 3 — Ask it things (5 min)

Open the agent. Two ways:

**Direct link** (bypasses the list — easiest if your account has many agents):
```
https://app.snowflake.com/#/agents/SNOWFLAKE_INTELLIGENCE/AGENTS/PAWCORE_ASSISTANT
```

**Or via Snowsight UI**: AI & ML → Snowflake Intelligence → pick **PawCore Assistant** from the list.

> **Optional — Add to CoWork:** To use the agent in Snowflake's collaborative chat (CoWork), go to **AI & ML → Snowflake Intelligence → CoWork → Add agent** and select `PAWCORE_ASSISTANT`. This is a manual UI step — there's no SQL/CLI equivalent. Not required for this exercise, but nice if you want to share the agent with teammates later.

Try these 3 questions in order. Watch what the agent does — it'll write SQL, run it, summarize, and sometimes follow up on its own.

### Question 1 — Diagnostic

> "Which lot has the worst customer ratings, and why?"

**What to look for:**
- Agent queries `mart_regional_customer_impact` or `CUSTOMER_REVIEWS` + `QUALITY_LOGS`
- Identifies LOT341 / EMEA
- Cross-references to quality data (failed moisture tests)
- Summarizes in 2-3 sentences

### Question 2 — Correlation

> "Which lot has the highest humidity readings, and how does that correlate with moisture-resistance QA failures and battery performance?"

**What to look for:**
- Agent uses `mart_lot_quality_correlation` or `mart_battery_moisture_correlation`
- Identifies **LOT341** as the outlier across all three dimensions:
  - Highest humidity (~77% vs ~60% for healthy lots)
  - Lowest QA pass rate (~88.6% vs ~96.9%), most failures (40 vs 11)
  - Lowest average battery (~78% vs ~92-94%), 502 low-battery incidents (vs 0 for others)
- States the causal chain: high humidity → failed moisture-resistance tests → battery degradation in the field
- Optional: suggests a bar chart or mentions EMEA region

### Question 3 — Action

> "If you were the head of product, what would you do next?"

**What to look for:**
- Agent reasons across findings from Q1 and Q2
- Recommends: stop-ship LOT341, investigate moisture resistance on the failed lots, refund/replace EMEA customers
- This is the "so what?" — a human analyst's synthesis, generated live from YOUR pipeline

---

## Checkpoint

> **Share in chat:** What's the most surprising thing your agent told you? Did it connect humidity to customer ratings on its own?

---

## Why this closed the loop

Go back to the top of this file. Your pipeline did three things:

1. **Schemas via DCM** — infrastructure you could review, version, deploy
2. **Marts via dbt** — business logic, tested, documented
3. **Agent via Snowflake Intelligence** — natural-language interface to all of it

Nobody on your team had to write a BI tool. Nobody had to build a custom RAG system. The semantic view + agent did it in one schema.

And every step of the way, CoCo was your pair programmer.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `CREATE AGENT` fails with privilege error | Missing `CREATE AGENT` grant | `GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE ACCOUNTADMIN` |
| Agent answers "I don't know" | Semantic view not picked up | Verify `SHOW SEMANTIC VIEWS` returns `PAWCORE_ANALYSIS`; re-attach as tool in agent config |
| Agent hallucinates column names | Missing column descriptions in semantic view | Open semantic view YAML, add `description` to each column |
| Region values look weird (Americas vs AMERICAS) | Case mismatch between staging + agent prompt | Filter in the agent orchestration: "region values in the data are: AMERICAS, EMEA, APAC" |

---

## Next steps after the webinar

- Extend the agent with more tools (Cortex Search over slack messages for unstructured context)
- Push your mart from Activity 2 into the semantic view so the agent can answer YOUR question too
- Run the full [Cortex AI + Snowflake Intelligence HOL](https://github.com/sfc-gh-calexander/HandsOnLabs/tree/main/1-Cortex-AI-Snowflake-Intelligence) for the deep version of this final step
