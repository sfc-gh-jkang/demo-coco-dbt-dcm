# Facilitator Runbook — 60-minute Active HOL

**Title:** Prompt to Pipeline: Build a dbt + DCM Data Pipeline in Snowflake with Cortex Code
**Presenter:** John Kang, Sales Engineer, Snowflake
**Duration:** 60 minutes
**Format:** Active HOL — attendees prompt their own Cortex Code instance, not just watch

## Pre-webinar checklist (T-24h)

- [ ] Attendees have confirmed trial account signup — verify list
- [ ] Pre-work email sent linking to `docs/attendee_quickstart.md` (trial + CLI + CoCo install + clone repo + edit `.env`)
- [ ] Cortex Code is installed on presenter laptop; `cortex connections list` shows working trial connection
- [ ] `scripts/deploy.py` dry-run end-to-end < 15 min on a fresh trial
- [ ] `snowflake/create_semantic_view.sql` produces a working `PAWCORE_ANALYSIS` view
- [ ] `snowflake/create_agent.sql` creates `PAWCORE_ASSISTANT` OR Snowsight UI path verified
- [ ] Sample agent questions all return sensible answers:
  - "Which lot has the worst customer ratings?" → LOT341 EMEA
  - "Is there a correlation between humidity and battery life?" → yes, EMEA high humidity = low battery
  - "What should I do next?" → synthesis answer

## Demo account

| Env | Connection | Purpose |
|---|---|---|
| Maintainer's SE demo (replace with yours) | `aws_spcs` | Dev + rehearsal |
| Webinar day | Fresh trial (spin up 1h before) | Live demo |

## 60-minute agenda (active HOL)

| Time | Segment | What I do | What attendees do |
|---|---|---|---|
| 0:00–0:05 | Welcome + PawCore framing | Show slides 1-3 | Listen, follow along |
| 0:05–0:20 | Live bootstrap + DCM + raw load | `uv run scripts/deploy.py --stop-at raw-load` | Watch, ready their terminals |
| 0:20–0:30 | **Activity 1: CoCo explains what was built** | Silent; facilitate chat | Prompt their own CoCo 3 times, share in chat |
| 0:30–0:32 | Live: create dbt project + build | `uv run scripts/deploy.py --stop-at build` | Watch 48 tests pass |
| 0:32–0:45 | **Activity 2: Build-your-own mart** | Pick Option (a) and demo, help stragglers | Prompt CoCo, create mart, run build |
| 0:45–0:55 | **Activity 3: Plug in a Snowflake Intelligence agent** | Run `deploy.py` (no flags, completes steps 6-7), open Snowsight AI & ML | Create agent + ask 3 questions |
| 0:55–1:00 | Recap + Q&A + handoff | Show recap slide, link to Cortex AI HOL #1 | Ask questions, share takeaways |

---

## Segment 1 — Welcome + PawCore (0:00–0:05)

**Say:**
> "Welcome. Today we're going to prompt-program a production-shaped data pipeline in 60 minutes. Not watch me prompt — you're going to prompt your own Cortex Code. Let's set the scene: PawCore makes smart pet collars. EMEA customers are complaining. Leadership wants AI-ready data to find out why. By the end of the hour, you'll have an agent answering that question for you."

Show slides 1-3 (title, scenario, agenda).

---

## Segment 2 — Live bootstrap + DCM + raw load (0:05–0:20)

**Say:**
> "This segment is the only part where you watch me. After this, you're driving. I'm running the first 3 steps of deploy.py — bootstrap, DCM schemas, raw data. Takes about 8 minutes."

Run:
```bash
uv run scripts/deploy.py --stop-at raw-load
```

**Talking points while it runs:**
- Safety gate fired; I had to set `I_UNDERSTAND=1` — *"This prevents attendees from overwriting an existing TARGET_DATABASE."*
- Bootstrap creates the API integration with a PAT secret — *"Private-repo access without exposing the token to attendees."*
- DCM `create` + `deploy` — *"Schemas as infrastructure. Git-backed, plan-reviewed, deploy-controlled."*
- RAW load uploads CSVs from the local data/ folder to an internal stage, then COPY INTO. 21k telemetry rows in ~10 seconds.

**Checkpoint:** everyone should see `✓ Stopped at raw-load`. If attendees have errors (wrong connection name, missing PAT), handle in breakout chat while I continue.

---

## Segment 3 — Activity 1: CoCo explains what was built (0:20–0:30)

**Hand-off:**
> "Open `docs/exercises/01_explore.md`. Run the 3 prompts in your own CoCo. I'll be quiet for 8 minutes. Paste your CoCo's one-line summary of DCM into chat as you go."

**My job for the 8 min:**
- Monitor chat, feature interesting answers
- Highlight diversity ("Alex's CoCo emphasized the plan/review loop, Sam's focused on the idempotent deploy")
- Call out if attendees are getting stuck on connection issues

**Re-engage at 0:28:**
> "2-minute warning. Anyone have a good one to share?"

Pick 2-3 chat messages, narrate why they're good.

---

## Segment 4 — Live build (0:30–0:32)

```bash
uv run scripts/deploy.py --stop-at build
```

**Say:**
> "48 tests. 4 staging views. 4 HOL tables. 3 marts. Under 30 seconds. Every test green. Let's use this."

---

## Segment 5 — Activity 2: Build-your-own mart (0:32–0:45)

**Say:**
> "Open `docs/exercises/02_build_mart.md`. Pick Option A, B, or C. I'll demo Option A so you see the shape of a working prompt. Then you pick."

**Demo (3 min):** live-prompt CoCo for Option A:
```
I'm adding a new dbt mart to this project. Please:
1. Read dbt/models/marts/_exercise_starter.sql and the 3 existing marts
2. Also read dbt/models/staging/stg_telemetry.sql
3. Write dbt/models/marts/mart_weekly_battery_by_region.sql

Business question: "How is battery performance trending by region week over week?"
Expected columns: week_start, region, avg_battery_level, min_battery_level, device_count

Use CTEs. Pre-aggregate to avoid fanout. ORDER BY at the end.
```

Narrate as CoCo writes: *"Notice it's using DATE_TRUNC — good. It's pulling from `stg_telemetry`, not RAW — even better."*

Run the build:
```sql
EXECUTE DBT PROJECT PAWCORE_DBT_DEMO.PUBLIC.PAWCORE_DBT args='build --select mart_weekly_battery_by_region+';
```

**Hand-off (10 min):**
> "Your turn. Pick B or C (or A if you want the easier one). I'll be quiet. Paste one line of what your CoCo built into chat when you're done."

**At 0:43:** 2-min warning, feature 2 chat answers.

---

## Segment 6 — Activity 3: Agent (0:45–0:55)

**Say:**
> "Last piece. We have marts. We have tests. We have schemas. Now we attach a Snowflake Intelligence agent and ask it business questions in English."

Run:
```bash
uv run scripts/deploy.py   # resumes and creates semantic view + agent
```

While it runs, open `docs/exercises/03_agent.md` in browser. Show sample questions.

Open Snowsight → **AI & ML** → **Snowflake Intelligence** → **PAWCORE_ASSISTANT**.

**Demo (3 min):**
Ask: `"Which lot has the worst customer ratings, and why?"`

Narrate as the agent:
1. Thinks (watch the thinking step)
2. Writes SQL against `PAWCORE_ANALYSIS` semantic view
3. Runs it
4. Summarizes: LOT341, EMEA, 4.10 avg rating, low battery correlation

**Hand-off (6 min):**
> "Ask the agent the other 2 questions from the exercise doc. Or ask it something of your own. Share what you got in chat."

---

## Segment 7 — Recap + Q&A (0:55–1:00)

Show recap slide.

**Say:**
> "In 60 minutes you prompted CoCo, built a mart, attached an agent. You have a working pipeline AND a business insight delivery tool. The marts you built today are the foundation for any agentic analytics product you want to ship.
>
> Next step: go take the Cortex AI HOL #1 — it builds out a fuller semantic view and adds Cortex Search over the Slack messages for unstructured context. Your pipeline plugs straight in.
>
> Questions?"

Show slide 6 (resources, QR code).

---

## Gotchas / recovery moves (updated for active HOL)

| Symptom | Cause | Fix |
|---|---|---|
| Attendee's `deploy.py` aborts at safety gate | Expected | Point them to `.env`, flip I_UNDERSTAND to 1 |
| Attendee can't push to repo (PAT 403) | Their fork, not mine | Tell them to work locally — they don't need to push for Activity 2, the dbt build reads from git so they need to commit somewhere. Fallback: run mart as one-off CREATE TABLE in Snowsight (docs/exercises/02_build_mart.md "Can't push to the repo?") |
| `CREATE AGENT` SQL fails with privilege error | Missing CREATE AGENT grant on their trial | Falls back to Snowsight UI path in exercise doc. Mention it's a 1-click UI form, same result. |
| Agent returns "I don't know" on obvious questions | Semantic view didn't pick up | `SHOW SEMANTIC VIEWS` to verify; re-run `create_semantic_view.sql` |
| Warehouse suspended mid-demo | AUTO_SUSPEND = 300 | First query auto-resumes; 2-3s wait |
| CoCo variable outputs across attendees | Different CoCo versions / model choices | Embrace it — this is part of the story. Feature diverse answers in chat. |
| Attendees fall way behind | Connection issues | `uv run scripts/deploy.py --resume` gets them to the current segment. If still behind at 0:40, tell them to skip Activity 2 and join live at 0:45 for the agent. |

---

## Stretch goals (if you finish early)

The hour is paced for ~50 actual content min + 10 min buffer. If everything goes smoothly, you may have 5–10 min left at 0:55 before the recap. Pick one:

### A. "Ask Slack" — demonstrate Cortex Search hook (3-5 min)

The semantic view doesn't include `SLACK_MESSAGES` because that's unstructured text. Show that the agent currently can't answer engineering-context questions, then preview Cortex Search:

> "Ask the agent: *'What were the engineers saying about moisture issues?'* — it'll fall back to the structured marts and miss the real answer. The Cortex AI HOL #1 adds a Cortex Search service over `SLACK_MESSAGES.text` and wires it to the agent as a second tool. That's your next hour."

Show 1-2 sample Slack messages mentioning moisture in Snowsight to make the gap concrete.

### B. "Build a test from a business rule" with CoCo (5 min)

Live-prompt CoCo:

```
Add a custom dbt singular test that fails if any LOT341 device has battery_level
above 95. Put it in dbt/tests/ and tell me how to run just that test.
```

CoCo writes the test, you run it (it should pass — no LOT341 device has high battery), then artificially break it ("change > 95 to > 50") to show it fails, then revert. Demonstrates: dbt tests as live business-rule guardrails authored by CoCo.

### C. "Edit + redeploy via DCM" (5–8 min)

> "Real production change: add a new schema for staging audit. Watch."

Live edit `dcm/sources/definitions/schemas.sql` to add `DEFINE SCHEMA ${TARGET_DB}.AUDIT`. Commit + push (or paste in Snowsight). Re-run `snow dcm plan` and show the diff. Then `snow dcm deploy`. Demonstrates: DCM's plan-review-deploy loop in <2 min, end to end.

### D. Q&A on architecture extension

Open question to the room: *"Where in this pipeline would you add Iceberg / streaming / Snowpipe? CoCo, what would change?"* Live-prompt CoCo to brainstorm. Less polished than A-C but engages people who came for the architecture conversation.

---

## Post-webinar

- [ ] Email attendees recording + repo link + link to Cortex AI HOL #1
- [ ] Run `snow sql -f teardown.sql -c <trial>` to clean my rehearsal account
- [ ] Collect 2-3 "best mart builds" from chat, share in follow-up email or social post
- [ ] Pre-webinar: `gh repo edit sfc-gh-jkang/demo-coco-dbt-dcm --visibility public` (after CASEC/LIFT approval)
