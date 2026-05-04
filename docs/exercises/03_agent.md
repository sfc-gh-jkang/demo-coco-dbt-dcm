# Activity 3 — Plug in a Snowflake Intelligence Agent

**Time:** 10 minutes · **You'll do:** create a semantic view over your marts, wire up a Snowflake Intelligence agent, ask it 3 questions in plain English

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

From your terminal or Snowsight:

```bash
snow sql -c <your-connection> -f snowflake/create_semantic_view.sql
```

Or prompt CoCo:

```
Run snowflake/create_semantic_view.sql against my connection and tell me what it created.
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

**Option A — CoCo prompt (recommended):**

```
Create a Snowflake Intelligence agent named PAWCORE_ASSISTANT in the
PAWCORE_ANALYTICS.SNOWFLAKE_INTELLIGENCE schema. The agent should:

- Use the semantic view PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS as its primary tool
- Have the description: "Senior business analyst for PawCore smart pet collars. Helps investigate quality, customer, and operational issues."
- Include orchestration instructions telling it to always look at multiple perspectives (manufacturing, customer, operational)
- Focus on LOT341/EMEA as the known problematic area

Give me the full CREATE AGENT statement and then run it.
```

CoCo will generate and execute the `CREATE AGENT` SQL.

**Option B — Snowsight UI fallback (if CREATE AGENT SQL fails):**

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

Try these 3 questions in order. Watch what the agent does — it'll write SQL, run it, summarize, and sometimes follow up on its own.

### Question 1 — Diagnostic

> "Which lot has the worst customer ratings, and why?"

**What to look for:**
- Agent queries `mart_regional_customer_impact` or `CUSTOMER_REVIEWS` + `QUALITY_LOGS`
- Identifies LOT341 / EMEA
- Cross-references to quality data (failed moisture tests)
- Summarizes in 2-3 sentences

### Question 2 — Correlation

> "Is there a correlation between humidity and battery life? Show me the data."

**What to look for:**
- Agent uses `mart_battery_moisture_correlation`
- Returns a table or chart showing humidity vs. battery
- Notes EMEA has highest humidity AND lowest battery — that's the correlation
- Optional: suggests a bar chart

### Question 3 — Action

> "If you were the head of product, what would you do next?"

**What to look for:**
- Agent reasons across findings from Q1 and Q2
- Recommends: stop-ship LOT341, investigate moisture resistance on the failed lots, refund/replace EMEA customers
- This is the "so what?" — a human analyst's synthesis, generated live from YOUR pipeline

---

## Checkpoint: paste into chat

What was the most interesting thing YOUR agent answered? Post one line into the webinar chat.

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
| `CREATE AGENT` fails with privilege error | Missing `CREATE AGENT` grant | `GRANT CREATE AGENT ON SCHEMA PAWCORE_ANALYTICS.SNOWFLAKE_INTELLIGENCE TO ROLE ACCOUNTADMIN` |
| Agent answers "I don't know" | Semantic view not picked up | Verify `SHOW SEMANTIC VIEWS` returns `PAWCORE_ANALYSIS`; re-attach as tool in agent config |
| Agent hallucinates column names | Missing column descriptions in semantic view | Open semantic view YAML, add `description` to each column |
| Region values look weird (Americas vs AMERICAS) | Case mismatch between staging + agent prompt | Filter in the agent orchestration: "region values in the data are: AMERICAS, EMEA, APAC" |

---

## Next steps after the webinar

- Extend the agent with more tools (Cortex Search over slack messages for unstructured context)
- Push your mart from Activity 2 into the semantic view so the agent can answer YOUR question too
- Run the full [Cortex AI + Snowflake Intelligence HOL](https://github.com/sfc-gh-calexander/HandsOnLabs/tree/main/1-Cortex-AI-Snowflake-Intelligence) for the deep version of this final step
