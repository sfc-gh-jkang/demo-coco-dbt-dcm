# PawCore Agent Prompt Guide

Questions to ask the **PawCore Assistant** agent, organized by investigation flow. Each question is backed by a Verified Query for accurate, fast responses.

---

## Getting Started (Onboarding Questions)

These appear automatically when you first open the agent:

1. **"Which lot has the worst battery performance?"**
   → Returns LOT341 at 87% avg battery (vs 92-94% for others)

2. **"Compare all lots by battery level and pass rate"**
   → Side-by-side comparison table of all 3 lots

3. **"How does humidity correlate with battery levels across lots?"**
   → Shows LOT341's humidity + battery + moisture resistance scores

4. **"What are the customer ratings by lot and region?"**
   → LOT341/EMEA at 4.10 is the lowest

5. **"What is the root cause of battery issues?"**
   → Cross-domain join: moisture, battery, and customer ratings together

6. **"Give me a full analysis of LOT341"**
   → Complete deep dive: battery, QA pass rate, ratings, humidity, moisture score

7. **"Give me an executive summary of the PawCore data"**
   → High-level lot comparison for leadership

---

## Investigation Flow (Recommended Sequence)

### Phase 1: Identify the Problem

| # | Question | Expected Insight |
|---|----------|-----------------|
| 1 | "Which lot has the worst battery performance?" | LOT341 at 87% (others are 92-94%) |
| 2 | "What is the QA pass rate for each lot?" | LOT341 is slightly lower but not dramatically |
| 3 | "What are the customer ratings by lot and region?" | LOT341/EMEA = 4.10/5 (lowest) |

### Phase 2: Quantify the Impact

| # | Question | Expected Insight |
|---|----------|-----------------|
| 4 | "How many devices are in each lot?" | LOT341 has 2,100 (largest lot!) |
| 5 | "How many unhappy customers are there per lot?" | LOT341 has the most 1-2 star reviews |
| 6 | "Which devices have critically low battery readings?" | Shows specific device_ids below 20% battery |

### Phase 3: Find the Root Cause

| # | Question | Expected Insight |
|---|----------|-----------------|
| 7 | "How does humidity correlate with battery levels?" | High humidity → low battery in LOT341 |
| 8 | "What are the moisture resistance test scores?" | LOT341 has lowest moisture_resistance score |
| 9 | "What are the moisture threshold test results by lot?" | Shows specific test measurements |
| 10 | "Show all failed QA tests" | Lists which tests failed for LOT341 |

### Phase 4: Root Cause Conclusion

| # | Question | Expected Insight |
|---|----------|-----------------|
| 11 | "What is the root cause of battery issues?" | Joins moisture + battery + ratings — clear correlation |
| 12 | "Compare healthy lots vs the problematic lot" | Side-by-side proof that LOT341 is the outlier |
| 13 | "Give me a full analysis of LOT341" | Complete picture for the incident report |

---

## Quick Data Checks

| Question | Purpose |
|----------|---------|
| "How many total devices are being tracked?" | Quick count (3,500 devices) |
| "How many customer reviews do we have?" | Quick count (1,550 reviews) |
| "What are the battery statistics for each lot?" | Min/max/avg per lot |
| "What are the QA results broken down by test type?" | Detailed test breakdown |
| "What is the distribution of customer ratings?" | Rating histogram by lot |

---

## Pro Tips

- **Start broad, then drill down**: "Executive summary" → "LOT341 deep dive" → "Failed QA tests"
- **The agent uses logical names**: It references `lot_battery`, `regional_rating`, etc. — these map to the semantic view
- **VQR-backed answers are faster**: Questions similar to the 22 pre-verified queries get instant, accurate SQL
- **Try rephrasing**: "worst lot" / "problematic batch" / "which lot has issues" should all trigger similar VQRs
- **Cross-domain is the wow moment**: The root cause query joins 3 marts to prove humidity → battery → low ratings

---

## Expected Conclusions

By the end of the investigation, the agent should help you conclude:

> **LOT341** (EMEA, 2,100 devices) has a manufacturing defect related to
> **moisture resistance**. Devices exposed to high humidity experience accelerated
> battery degradation (avg 87% vs 92-94% for healthy lots), leading to lower
> customer satisfaction ratings (4.10/5 vs 4.14-4.29). The moisture threshold QA
> tests show LOT341 has the lowest scores, confirming insufficient sealing.
