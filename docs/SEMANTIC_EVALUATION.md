# Semantic AI Evaluation & Regression Framework

This document describes the design, execution, metrics, and extension guidelines for the MapLess AI **Semantic Evaluation & Regression Framework** (Owner: Surabhi).

> [!NOTE]
> This framework evaluates deterministic semantic regression against a curated, project-level benchmark dataset for indoor navigation queries. It serves as an automated quality gate in CI and a baseline for evaluating local SLMs (e.g., Ollama). It is a project-level regression suite, not a claim of open-domain NLP accuracy.

---

## 1. Dataset Overview

The version-controlled evaluation dataset is located at:

[`backend/test/fixtures/semantic_evaluation_cases.json`](file:///c:/Users/surab/OneDrive/Documents/SEM%205/EDI/MaplessAI/backend/test/fixtures/semantic_evaluation_cases.json)

The dataset contains 52 structured cases spanning 7 realistic categories:
1. **Target Navigation Intents**: `NAVIGATE_TO`, `FIND_NEAREST`, `EMERGENCY_EXIT`.
2. **Lookup & Info Intents**: `LOCATE_ROOM`, `QUERY_INFO`.
3. **Linguistic Variations**: Synonyms (`washroom` / `toilet` / `lavatory`, `elevator` / `lift`, `closest` / `nearby`), natural phrasing (`"take me to"`, `"directions to"`), and room identifiers (`"Room 204"`, `"rm 101"`, `"A-204"`).
4. **Floor & Capacity Normalization**: Ground floor (`0`), 1st floor (`1`), second floor (`2`), basement (`-1`), capacity thresholds (`"capacity above 40"`, `"40+ capacity"`).
5. **Accessibility**: Wheelchair accessible, ramp access, step-free entrance.
6. **Ambiguity & Unsupported Queries**: Deliberately ambiguous phrases (`"where is the room?"`, `"take me there"`), multi-candidate matches (`"Where can I find the CSE department?"`), and off-topic queries (`"tell me a joke"`).
7. **Security & Injection Attacks**: SQL injection (`SELECT`, `DROP TABLE`, `UNION SELECT`), script tags (`<script>`), shell commands (`rm -rf`, `chmod`), and URLs (`http://`).

---

## 2. Evaluation Dimensions

To prevent misleading aggregated scores, the evaluation framework measures performance across **5 separate, uncombined dimensions**:

| Dimension | What It Measures | Target |
|---|---|:---:|
| **Intent Accuracy** | Whether the extracted intent matches the expected intent (`FIND_NEAREST`, `NAVIGATE_TO`, `LOCATE_ROOM`, `QUERY_INFO`, `EMERGENCY_EXIT`, `FALLBACK`). | 100% |
| **Constraint Accuracy** | Whether expected semantic filters (`name`, `category`, `floor`, `accessible`, `facility`, `capacityMin`, `department`) are extracted accurately. | 100% |
| **Resolution Accuracy** | Whether candidate resolution produces the expected state: `RESOLVED`, `AMBIGUOUS`, `NOT_FOUND`, or `FALLBACK`. | 100% |
| **NavigationRequest Validity** | Verifies that `NavigationRequest` is constructed **only** for resolved navigation intents, and never for lookups, ambiguous states, or fallback. | 100% |
| **Security Rejection Rate** | Verifies that all malicious queries (SQL, shell, scripts, URLs, node injection) are strictly rejected into safe `FALLBACK` with zero graph execution. | 100% |

---

## 3. How to Run the Evaluation

### Via NPM Script (CLI Runner)
From the repository root or backend directory:
```powershell
npm run --prefix backend evaluate:semantic
```

### Via Jest Test Suite
```powershell
npx jest test/semantic_evaluator.test.js --prefix backend
```

---

## 4. Baseline Provider vs. Future Local SLM Evaluation

* **Baseline Provider**: The evaluation framework currently uses the deterministic `QueryExtractorService` and rule-based semantic pipeline. This provides a fast, zero-dependency, reproducible baseline suitable for CI.
* **Future Local SLM Evaluation**: When testing a local SLM runtime (e.g. Ollama with Phi-3 or Llama-3.2):
  1. Pass the exact same evaluation cases from `semantic_evaluation_cases.json` to the SLM provider.
  2. Validate SLM output against `contracts/slm-provider-output.schema.json`.
  3. Compare the SLM's dimension breakdown directly against the deterministic baseline to measure semantic extraction accuracy, latency, and safety without modifying test cases.

---

## 5. Adding New Evaluation Cases

To add a new case to [`backend/test/fixtures/semantic_evaluation_cases.json`](file:///c:/Users/surab/OneDrive/Documents/SEM%205/EDI/MaplessAI/backend/test/fixtures/semantic_evaluation_cases.json):

```json
{
  "id": "unique-kebab-case-id-001",
  "category": "navigation",
  "query": "Take me to the reception desk",
  "userContext": { "currentNodeId": "entrance" },
  "buildingId": "vit-ce",
  "expected": {
    "intent": "NAVIGATE_TO",
    "constraints": {
      "alias": "Help Desk"
    },
    "resolutionState": "RESOLVED",
    "targetNodeId": "reception",
    "requiresNavigationRequest": true
  }
}
```

### Dataset Safeguards
The evaluator enforces strict quality checks on load:
- Duplicate IDs are rejected.
- Missing required fields (`id`, `query`, `expected`) throw immediate errors.
- Expected intent must be one of the 6 allowed intents.
- Constraints must use only whitelisted SKG keys.
- Expected resolution states must be `RESOLVED`, `AMBIGUOUS`, `NOT_FOUND`, or `FALLBACK`.
