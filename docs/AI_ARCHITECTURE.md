# MapLess AI — Small Language Model (SLM) & Semantic AI Architecture

## 1. Role & Responsibilities (Owner: Surabhi)

The AI layer within MapLess AI enables conversational indoor navigation by transforming natural-language user utterances into validated, structured spatial queries.

### Core Philosophy
1. **No Hallucinated Geography**: The SLM does **not** make assumptions about building layout, coordinates, or connectivity. All spatial ground truth resides strictly in the deterministic graph database.
2. **Strict Security Boundary**: The SLM is strictly prohibited from generating, issuing, or executing SQL queries, database commands, or filesystem mutations.
3. **Contract-Enforced Output**: The SLM must output valid JSON conforming to `contracts/ai-response.schema.json`.

---

## 2. Natural Language Processing Pipeline

```
[ User Utterance ]
  "Where is the nearest computer lab with wheelchair access?"
        │
        ▼
[ SLM Inference / Tokenizer ]
  • Intent Recognition
  • Named Entity Recognition (NER)
  • Constraint Parsing
        │
        ▼
[ Structured Intermediate Representation ]
{
  "intent": "FIND_NEAREST",
  "entities": [
    { "type": "category", "value": "laboratory" },
    { "type": "keyword", "value": "computer" }
  ],
  "constraints": {
    "category": "laboratory",
    "accessible": true
  },
  "confidence": 0.94
}
        │
        ▼
[ Backend Schema Validator ] ──(Fails)──► [ Fallback Handler ]
        │ (Passes)
        ▼
[ Semantic Knowledge Graph Matcher ]
  • Queries semantic_metadata tags and aliases
  • Evaluates operational hours & constraints
  • Ranks candidate nodes: ["lab-101"]
        │
        ▼
[ Deterministic Graph Engine (Pratik) ]
  • Computes path from visitor's current node to "lab-101"
        │
        ▼
[ Response Formatter ] ──► [ Flutter AI Chat Screen (Nishant) ]
```

---

## 3. Intent Taxonomy

| Intent Code | Description | Example Utterance |
| :--- | :--- | :--- |
| `FIND_NEAREST` | Locate the closest node matching specific category or tags relative to current location | "Where is the nearest restroom?", "Find the closest water cooler" |
| `NAVIGATE_TO` | Direct point-to-point navigation to a specific named room, lab, or person's office | "Take me to Lab 101", "How do I get to the Library?" |
| `LOCATE_ROOM` | Information lookup on room identity or floor level without immediate navigation | "Which floor is the Dean's office on?", "Where is the Seminar Hall?" |
| `QUERY_INFO` | Inquiries regarding operational hours, room amenities, capacity, or departments | "Is Lab 101 open right now?", "Does the library have Wi-Fi?" |
| `EMERGENCY_EXIT`| High-priority immediate routing to the nearest active, non-blocked emergency exit | "Where is the fire exit?", "Evacuation route please" |
| `FALLBACK` | Emitted when confidence is below threshold or query is ambiguous/unsupported | "Tell me a joke", "What is the weather outside?" |

---

## 4. Entity Extraction Rules

The SLM pipeline extracts normalized entities across standard indoor dimensions:

1. **Room / Facility Categories**: Normalized against the system vocabulary (`laboratory`, `office`, `restroom`, `library`, `classroom`, `canteen`, `elevator`, `stairs`, `emergency_exit`).
2. **Room Numbers / Codes**: Normalized alphanumeric codes (e.g., "101", "Lab-101", "B-204").
3. **Departments**: Academic or administrative units ("Computer Engineering", "IT", "Dean Office").
4. **Amenities & Keywords**: Extracted descriptors ("projector", "quiet", "air conditioned", "computers").
5. **Constraints**:
   - `accessible`: Boolean flag triggered by terms like "wheelchair", "accessible", "no stairs", "elevator only".
   - `floor`: Integer floor number extracted from "first floor", "ground floor", "level 2".

---

## 5. Security & Safety Invariants

> **CRITICAL INVARIANT:**
> Under no circumstances may the SLM output dynamic SQL (`SELECT * FROM nodes...`), Cypher queries, or REST endpoint URLs.
> If an SLM produces SQL or unstructured text, the Backend Schema Validator rejects the payload and triggers the safe fallback response:
>
> ```json
> {
>   "intent": "FALLBACK",
>   "entities": [],
>   "constraints": {},
>   "confidence": 0.0,
>   "responseMessage": "I could not understand that request. You can ask me to find rooms, labs, elevators, or emergency exits."
> }
> ```

---

## 6. Offline / Edge Small Language Model Considerations

MapLess AI is architected to support local on-device or lightweight edge SLMs (e.g., quantized SmolLM, Phi-3-mini, or Gemma 2B):
- The model prompt is strictly bounded with a system prompt and standard few-shot input/output examples conforming to `contracts/ai-query.schema.json` and `contracts/ai-response.schema.json`.
- When offline on device, a regex/rule-based intent parser acts as an immediate fallback if the local SLM is downloading or unavailable.
