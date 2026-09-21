# Semantic AI Failure Handling & Reliability Guide

## Overview & System Boundaries

The Semantic AI subsystem in MapLess AI converts natural-language indoor queries into structured Semantic Knowledge Graph (SKG) queries and constructs a `NavigationRequest` when a single destination is unambiguously resolved.

### Strict Architectural Boundaries
1. **Semantic AI Layer Responsibility (Surabhi):**
   - Natural language parsing, intent/entity/constraint extraction.
   - Provider abstraction, contract validation, and security scanning.
   - Structured graph query generation.
   - Deterministic candidate resolution against building knowledge graphs.
   - Ambiguity detection, fallback execution, and safe `NavigationRequest` packaging.
2. **Spatial Routing Subsystem Responsibility (Pratik):**
   - Physical route calculation (A*, Dijkstra).
   - Sensor fusion, indoor positioning, and turn-by-turn guidance.
   - Rendering paths on the mobile canvas.
3. **Core Reliability Axiom:**
   > *When uncertain, the system must fail safely rather than invent a destination, route, or fake candidate.*

---

## 1. The Failure-State Pipeline

```text
Incoming Natural Language Query
               │
               ▼
   [1. Input Validation (ai-query)] ─── Invalid / Too Long (>1000) ──► HTTP 400 Validation Error
               │
               ▼
   [2. SLM Extraction / Provider] ───── Runtime Error / Timeout ─────► HTTP 200 Controlled FALLBACK (conf=0.0)
               │
               ▼
   [3. Output Contract Validation] ─── Malformed / Injected ────────► HTTP 200 Controlled FALLBACK (conf=0.0)
               │
               ▼
   [4. Structured Graph Query Gen] ─── Contradiction / Low Conf ────► HTTP 200 Controlled FALLBACK / AMBIGUOUS
               │
               ▼
   [5. Semantic Graph Resolution]
               │
               ├── Multiple Matches (AMBIGUOUS) ─────────► HTTP 200 AMBIGUOUS (targetNodeId=null, no navRequest)
               ├── Zero Matches (NOT_FOUND) ─────────────► HTTP 200 NOT_FOUND (targetNodeId=null, no navRequest)
               ├── Graph Resolver Failure / Corrupt Data ► HTTP 200 Controlled FALLBACK (conf=0.0, no leaked paths)
               └── Exactly 1 Match (RESOLVED)
                       │
                       ├── Lookup Intent (LOCATE_ROOM, etc.) ──► HTTP 200 Info (targetNodeId, no navRequest)
                       └── Navigation Intent (NAVIGATE_TO, etc) ─► HTTP 200 + Validated NavigationRequest
```

---

## 2. Resolution States

| State | Condition | Target Node ID | NavigationRequest | Response Intent | Confidence |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `RESOLVED` | Exactly 1 graph candidate matches all active constraints | Valid node ID | Produced only if intent requires routing | Preserved | Preserved ($\le \text{provider}$) |
| `AMBIGUOUS` | 2 or more candidates match, or query lacks destination details | `null` | Strictly `null` | `FALLBACK` | Capped at $\min(\text{conf}, 0.50)$ |
| `NOT_FOUND` | Valid criteria provided, but 0 candidates match in the building | `null` | Strictly `null` | `FALLBACK` | Strictly `0.0` |
| `FALLBACK` | Unrecognized query, contradictory constraints, or security violation | `null` | Strictly `null` | `FALLBACK` | Strictly $\le 0.50$ (typically `0.0`) |

---

## 3. Ambiguity & Contradictory Constraint Rules

### A. Conflicting Constraint Detection
The system proactively scans for and neutralizes contradictory constraints before invoking the graph engine:
1. **Conflicting Categories:** Asking for multiple mutually exclusive amenities in a single destination query (e.g. *"Take me to the lab and the elevator and the restroom"*) returns `FALLBACK` with `ambiguity: true`.
2. **Conflicting Floors:** Mentions of multiple distinct floors (e.g. *"Find the lab on floor 1 and floor 2"*) returns `FALLBACK` with `ambiguity: true`.
3. **Conflicting Rooms:** Mentions of multiple distinct room numbers (e.g. *"Take me to room 101 and room 204"*) returns `FALLBACK` with `ambiguity: true`.
4. **Conflicting Accessibility:** Simultaneous specification of accessibility requirements and non-accessible restrictions (e.g. *"Wheelchair accessible entrance stairs only"*) returns `FALLBACK` with `ambiguity: true`.
5. **Conflicting Capacity:** Contradictory threshold ranges where minimum capacity exceeds maximum capacity (e.g. *"Room with capacity over 100 but under 20"*) returns `FALLBACK` with `ambiguity: true`.

### B. Generic References
Queries such as *"take me there"*, *"that room"*, or *"find it"* provide insufficient destination criteria. They are safely classified as ambiguous/fallback and never silently select a random or default location.

---

## 4. Confidence Monotonicity

Confidence is monotonically non-increasing across the entire pipeline. No downstream component may artificially inflate confidence:

$$\text{Final Response Confidence} \le \text{Graph Query Confidence} \le \text{SLM Provider Confidence}$$

### Explicit Rules:
1. **Ambiguity Cap:** If candidate resolution is ambiguous, confidence cannot exceed `0.50`.
2. **Not-Found Floor:** If candidate resolution finds zero matches, confidence is immediately set to `0.0`.
3. **Gate Enforcement:** Requests with confidence $< 0.50$ trigger the controller gate, suppressing `NavigationRequest` creation and destination resolution.

---

## 5. Provider Failure Policy

### Isolation & Information Hiding
The API encapsulates all SLM provider interactions within isolated exception handlers:
- **Timeouts:** AbortController signals trigger a clean `FALLBACK` with `reason: "local SLM request timed out"`.
- **Connection Errors:** `ECONNREFUSED` or unreachable runtimes return `FALLBACK` with `reason: "local SLM runtime unavailable"`.
- **Malformed Outputs:** Invalid JSON or non-conforming schemas are intercepted by contract validation and returned as safe fallback payloads.
- **Privacy Guarantee:** Internal runtime URLs, ports, filesystem paths, and environment variables are never leaked in error payloads.
- **No Silent External API Calls:** When the local SLM is unavailable, the system never silently offloads queries to external third-party cloud APIs.

---

## 6. Semantic Graph Resilience

1. **Defensive Attribute Matching:** `_matchesConstraints` defends against missing or corrupted node metadata (null names, non-array aliases, missing categories) without throwing unhandled exceptions.
2. **Deterministic Candidate Ordering:** When multiple candidates match, candidate arrays are sorted ascending by `node.id`, guaranteeing 100% idempotent responses across runs.
3. **Resolver Exception Containment:** Unexpected graph read exceptions are caught by the controller and translated into standard HTTP 200 fallback responses.

---

## 7. NavigationRequest Safety Invariants

A `NavigationRequest` is emitted **ONLY** when **ALL** of the following conditions are simultaneously met:
1. Provider extraction conforms to `slm-provider-output` schema.
2. Query is free of malicious injection patterns.
3. Graph query operation is active (`RESOLVE_DESTINATION`, `FIND_NEAREST_TARGET`, or `RESOLVE_EMERGENCY_EXIT`).
4. Intent is a recognized navigation intent (`NAVIGATE_TO`, `FIND_NEAREST`, `EMERGENCY_EXIT`).
5. Candidate resolution produces **exactly 1** candidate (`status === 'resolved'`).
6. Confidence is $\ge 0.50$ and `ambiguity === false`.

`destinationNodeId` originates exclusively from the candidate ID returned by the Semantic Knowledge Graph. It can **never** be injected or overridden by model output or client request parameters.

---

## 8. What the API Deliberately Does NOT Attempt

To preserve clear architectural ownership and safety:
- **No Physical Pathfinding:** Does not calculate paths, step counts, meters, or node coordinates.
- **No Conversational Guessing:** Does not attempt to guess user intentions when constraints contradict.
- **No Sensor Fusion:** Does not infer indoor location from Wi-Fi signal strength or beacons.
- **No Database Execution:** Never runs SQL, PostgreSQL queries, or shell commands.
