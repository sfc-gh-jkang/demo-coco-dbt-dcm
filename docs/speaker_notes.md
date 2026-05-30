# Speaker Notes — Prompt to Pipeline Webinar

One paragraph per slide. Paste into the Slides notes pane in order.
Deck: `1YMC5y8gmOwGhrCwSGcZ0VDeKzKoyC9QT08tl5x_eax0` (9 slides)

Tone: conversational, time-aware, hand off cleanly. Bracketed `[time:X]`
markers are wall-clock targets in a 60-minute slot.

---

## s1_title — Prompt to Pipeline `[time: 0:00]`

Welcome. We have 60 minutes. Three things will be true at the end:
you will have prompted Cortex Code yourself, you will have built a dbt
mart from a prompt, and you will have a Snowflake Intelligence agent
answering questions over your own pipeline. Nothing pre-built — every
table, test, and agent gets generated live from prompts in front of
you. If you brought a Snowflake account and Cortex Code installed,
follow along. If not, watch — the recording and repo will let you
redo it tonight.

---

## s2_scenario — PawCore Smart Pet Collars `[time: 0:01]`

The story: PawCore makes smart pet collars. EMEA support tickets are
spiking, leadership wants to know why, and the data is scattered —
21K telemetry rows, 1,050 quality test results, 1,550 customer
reviews, 37 internal Slack messages. The punchline that the data
will reveal: LOT341 manufactured for EMEA has the worst customer
ratings AND the lowest battery life. We won't tell the agent that —
the agent will tell us. Our job in the next 59 minutes is to land
this data into business-ready marts and a semantic view that an
agent can reason over.

---

## s3_agenda — 60-Minute Breakdown `[time: 0:02]`

Quick map. Five minutes of framing, seven minutes of Cortex Code
tour and bootstrap, ten minutes on DCM deploying schemas from git,
twenty minutes on the dbt project — sources to staging to HOL
tables to marts, thirteen on validation plus plugging in an agent,
five-minute recap and Q&A. The three activity blocks in the middle
are YOUR hands-on time, not mine. If you fall behind, the repo has
a self-walkthrough that takes the same path at your pace.

---

## s4_divider — Let's build it `[time: 0:05]`

Switch to terminal. Open Cortex Code, open the demo-coco-dbt-dcm
repo. The next ten minutes I run `uv run scripts/deploy.py` steps 1-3
live: bootstrap the account, DCM creates schemas from `dcm/`, raw
CSVs land via `scripts/load_raw_data.py`. While that runs I narrate
what each step does. By 0:15 we should see RAW schema populated and
DCM-managed schemas in PAWCORE_ANALYTICS.

---

## s_act1 — Activity 1: Ask CoCo `[time: 0:15, 10 min]`

Your turn. Three prompts, ten minutes. Open YOUR Cortex Code, point
it at YOUR clone of the repo. Prompt 1 asks CoCo to read the DCM
manifest and explain in plain English what just deployed — this
proves CoCo reads code, not just data. Prompt 2 walks through
`stg_customer_reviews` so you see the staging-layer business logic.
Prompt 3 asks for raw-data row counts and a one-line insight. Drop
your favorite CoCo answer in the chat — I'll read out two or three
at the seven-minute mark. Full prompt text and what to look for is
in `docs/exercises/01_explore.md`.

---

## s_act2 — Activity 2: Build Your Own Mart `[time: 0:25, 13 min]`

Pick A, B, or C — easy, medium, or advanced. Easy is a weekly
battery trend by region. Medium is a top-10 problematic-devices
mart that joins all three staging models. Advanced is a device-age
versus failure-rate correlation. Prompt CoCo with the template in
`docs/exercises/02_build_mart.md`, let it write the SQL, run
`dbt build --select your_model+`, watch tests pass. Thirteen
minutes is enough — three to prompt, three for CoCo to write, four
for build, three to inspect results. If your build fails, that's
expected and useful — paste the error back to CoCo and let it fix
itself. That self-correction loop is half the value here.

---

## s_act3 — Activity 3: Plug in an Agent `[time: 0:38, 10 min]`

Run `uv run scripts/deploy.py` steps 6-7. That creates the
`PAWCORE_ANALYSIS` semantic view over your marts and the
`PAWCORE_ASSISTANT` agent. Open Snowsight, AI & ML, Snowflake
Intelligence, pick PAWCORE_ASSISTANT. Three questions — worst-rated
lot, humidity-vs-battery correlation, what-would-you-do-as-head-of-
product. Watch the trace: the agent picks dimensions, writes SQL
against the semantic view, summarizes. The third question is the
payoff — it pulls the LOT341/EMEA story out without ever being
told that's the answer. UI fallback steps in `docs/exercises/
03_agent.md` if the API path errors.

---

## s5_recap — What You Did `[time: 0:48]`

Three verbs. You PROMPTED CoCo with three real prompts against your
own instance. You BUILT a mart — your own dbt model, tested,
materialized in ANALYTICS, with CoCo writing the SQL and DCM-governed
schemas holding it. You ATTACHED an agent — Snowflake Intelligence
over your pipeline, natural-language questions in, structured answers
plus SQL out. The numbers: 8 schemas, 48 tests, 1 semantic view, 1
working agent — all prompted, none hand-written. That's the demo's
real point: this is now a 60-minute path, not a six-week project.

---

## s6_next — Next Steps + Resources `[time: 0:53, Q&A then close]`

Four things. One — clone the repo, run it tonight on your own
account: github.com/sfc-gh-jkang/demo-coco-dbt-dcm. Two — graduate
to Cortex AI HOL #1 for deeper agent work: link on slide. Three —
the self-guided walkthrough in `docs/self_walkthrough.md` mirrors
this session at your own pace. Four — reach out: john.kang@
snowflake.com or @sfc-gh-jkang on the SE channels. Open Q&A for
five minutes. Thank you.
