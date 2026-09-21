const semanticGraphService = require('./semantic_graph.service');

/**
 * Enhanced Query Extractor Service (Owner: Surabhi)
 *
 * Deterministic, rule-based extraction layer that converts natural-language campus
 * queries into controlled structured intents, entities, constraints, confidence scores,
 * ambiguity flags, and explainability reasons.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This service NEVER executes database, filesystem, shell, or network operations.
 * 2. It performs strictly deterministic, in-memory string parsing and extraction.
 * 3. Constraints are strictly whitelisted and typed.
 * 4. Never invents node IDs. Node resolution is left entirely to the SemanticGraphService.
 * 5. Avoids overmatching: generic words (e.g. bare "room") without identifiers are
 *    flagged as ambiguous, never guessed.
 */

const ALLOWED_CONSTRAINTS = Object.freeze([
  'nodeId',
  'name',
  'alias',
  'category',
  'tag',
  'department',
  'accessible',
  'facility',
  'floor',
  'capacityMin'
]);

class QueryExtractorService {
  /**
   * Extracts structured query data from natural language text and visitor context.
   *
   * @param {string} text Natural language query from user
   * @param {object} [userContext] Optional contextual state (accessible, floor, etc.)
   * @returns {{
   *   intent: string,
   *   entities: Array<{ type: string, value: string }>,
   *   constraints: object,
   *   confidence: number,
   *   ambiguity: boolean,
   *   reason: string
   * }}
   */
  extractQuery(text, userContext = null) {
    // ── Edge Case 1: Empty or whitespace-only text ──────────────────────────
    if (typeof text !== 'string' || !text.trim()) {
      return {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        reason: 'empty or whitespace-only query text'
      };
    }

    // ── Security Check: Reject SQL injection and script patterns ────────────
    const MALICIOUS_PATTERNS = [
      /\b(select\s+.+\s+from)\b/i,
      /\b(union\s+(all\s+)?select)\b/i,
      /\b(insert\s+into)\b/i,
      /\b(drop\s+table)\b/i,
      /\b(delete\s+from)\b/i,
      /--/,
      /<script\b[^>]*>/i,
      /javascript:/i
    ];
    if (MALICIOUS_PATTERNS.some(p => p.test(text))) {
      return {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        reason: 'malicious or injection pattern detected'
      };
    }

    const rawLower = text.toLowerCase();
    const cleanText = rawLower.replace(/[^\w\s+-]/g, ' ').replace(/\s+/g, ' ').trim();

    let intent = null;
    const entities = [];
    const rawConstraints = {};
    let confidence = 0.0;
    let ambiguity = false;
    let reason = 'unsupported or off-topic request';

    // ── 1. Normalization Helpers ────────────────────────────────────────────

    // A. Accessibility
    const hasAccessibleKeyword = /\b(accessible|wheelchair|handicap|step-free|stepfree|barrier-free|ramp|ramp\s+access)\b/i.test(cleanText);
    const userRequiresAccessible = userContext && userContext.accessible === true;
    if (hasAccessibleKeyword || userRequiresAccessible) {
      rawConstraints.accessible = true;
      entities.push({ type: 'accessibility', value: 'accessible' });
    }

    // B. Floor Normalization
    const floorNormalized = this._normalizeFloor(cleanText);
    if (floorNormalized !== null) {
      rawConstraints.floor = floorNormalized;
      entities.push({ type: 'floor', value: String(floorNormalized) });
    }

    // C. Capacity Normalization
    const capacityMin = this._normalizeCapacity(cleanText);
    if (capacityMin !== null) {
      rawConstraints.capacityMin = capacityMin;
      entities.push({ type: 'facility', value: `capacityMin:${capacityMin}` });
    }

    // D. Facilities & Amenities
    if (/\b(wifi|wi-fi|internet|wireless)\b/i.test(cleanText)) {
      rawConstraints.facility = 'wifiZone';
      entities.push({ type: 'facility', value: 'wifiZone' });
    }
    if (/\b(projector|projection|screen)\b/i.test(cleanText)) {
      rawConstraints.facility = 'projectorAvailable';
      entities.push({ type: 'facility', value: 'projectorAvailable' });
    }
    if (/\b(ac|air\s*conditioned|air\s*conditioning|central\s*ac)\b/i.test(cleanText)) {
      rawConstraints.facility = 'airConditioned';
      entities.push({ type: 'facility', value: 'airConditioned' });
    }
    if (/\b(braille|braille\s+buttons)\b/i.test(cleanText)) {
      rawConstraints.facility = 'brailleButtons';
      entities.push({ type: 'facility', value: 'brailleButtons' });
    }
    if (/\b(first\s*aid|emergency\s*kit|medical\s*kit)\b/i.test(cleanText)) {
      rawConstraints.facility = 'emergencyFirstAid';
      entities.push({ type: 'facility', value: 'emergencyFirstAid' });
    }

    // E. Category Synonyms
    const detectedCategory = this._normalizeCategory(cleanText);

    // F. Department Synonyms & Graph Lookups
    const detectedDepartment = this._normalizeDepartment(cleanText) || semanticGraphService.findDepartmentInText(text);
    if (detectedDepartment) {
      rawConstraints.department = detectedDepartment;
      entities.push({ type: 'department', value: detectedDepartment });
    }

    // G. Room Identifier / Name / Alias Normalization
    const matchedAlias = semanticGraphService.findAliasInText(text);
    const matchedName = semanticGraphService.findNameInText(text);
    const roomIdentifier = this._normalizeRoomIdentifier(cleanText);

    // Specific AI Lab tag recognition (e.g. "AI lab" matches tag 'ai' on lab-101)
    const isAiLab = /\b(ai\s+lab|ai\s+laboratory|artificial\s+intelligence\s+lab)\b/i.test(cleanText);
    if (isAiLab) {
      rawConstraints.category = 'laboratory';
      rawConstraints.tag = 'ai';
      entities.push({ type: 'category', value: 'laboratory' });
      entities.push({ type: 'alias', value: 'AI Lab' });
    }

    // ── 2. Conflicting / Contradictory Categories Check ─────────────────────
    const conflictingCategories = [];
    if (/\b(lab|labs|laboratory|laboratories)\b/i.test(cleanText)) conflictingCategories.push('laboratory');
    if (/\b(exit|exits|emergency|evacuat\w*)\b/i.test(cleanText)) conflictingCategories.push('emergency_exit');
    if (/\b(lift|lifts|elevator|elevators)\b/i.test(cleanText)) conflictingCategories.push('elevator');
    if (/\b(restroom|restrooms|washroom|washrooms|toilet|toilets|lavatory|lavatories)\b/i.test(cleanText)) conflictingCategories.push('restroom');

    if (conflictingCategories.length > 1) {
      return {
        intent: 'FALLBACK',
        entities: conflictingCategories.map(c => ({ type: 'category', value: c })),
        constraints: {},
        confidence: 0.40,
        ambiguity: true,
        reason: 'contradictory or multiple conflicting destination categories in query'
      };
    }

    // ── 3. Intent Determination Logic ───────────────────────────────────────

    // Pattern A: Emergency Exit / Evacuation
    if (/\b(exit|exits|emergency|evacuat\w*|fire\s+exit|fire\s+door)\b/i.test(cleanText)) {
      intent = 'EMERGENCY_EXIT';
      entities.push({ type: 'category', value: 'emergency_exit' });
      rawConstraints.category = 'emergency_exit';
      confidence = 0.95;
      reason = 'recognized emergency exit category';
    }
    // Pattern B: Nearest / Closest / Nearby Facility
    else if (/\b(nearest|closest|nearby)\b/i.test(cleanText)) {
      if (detectedCategory) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'category', value: detectedCategory });
        rawConstraints.category = detectedCategory;
        confidence = 0.90;
        reason = `recognized nearest request for category: ${detectedCategory}`;
      } else if (matchedAlias) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'alias', value: matchedAlias });
        rawConstraints.alias = matchedAlias;
        confidence = 0.85;
        reason = 'recognized nearest destination by alias';
      } else if (matchedName) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'room_name', value: matchedName });
        rawConstraints.name = matchedName;
        confidence = 0.85;
        reason = 'recognized nearest destination by room name';
      } else if (rawConstraints.facility) {
        intent = 'FIND_NEAREST';
        confidence = 0.85;
        reason = `recognized nearest request for facility: ${rawConstraints.facility}`;
      } else {
        intent = 'FALLBACK';
        confidence = 0.30;
        ambiguity = true;
        reason = 'nearest keyword present but no target destination specified';
      }
    }
    // Pattern C: Navigation Request ("take me", "navigate", "go to", "route to", "directions to")
    else if (/\b(take\s+me|navigate|go\s+to|route\s+to|directions\s+to|lead\s+me\s+to|how\s+to\s+get\s+to)\b/i.test(cleanText)) {
      intent = 'NAVIGATE_TO';
      if (isAiLab) {
        confidence = 0.90;
        reason = 'recognized navigation request for AI lab';
      } else if (matchedAlias) {
        entities.push({ type: 'alias', value: matchedAlias });
        rawConstraints.alias = matchedAlias;
        confidence = 0.90;
        reason = 'recognized navigation request for known alias';
      } else if (matchedName) {
        entities.push({ type: 'room_name', value: matchedName });
        rawConstraints.name = matchedName;
        confidence = 0.90;
        reason = 'recognized navigation request for known room name';
      } else if (roomIdentifier) {
        entities.push({ type: 'room_name', value: roomIdentifier });
        rawConstraints.name = roomIdentifier;
        confidence = 0.85;
        reason = `recognized navigation request for room: ${roomIdentifier}`;
      } else if (detectedCategory) {
        entities.push({ type: 'category', value: detectedCategory });
        rawConstraints.category = detectedCategory;
        confidence = 0.85;
        reason = `recognized navigation request for category: ${detectedCategory}`;
      } else if (/\b(library)\b/i.test(cleanText)) {
        entities.push({ type: 'category', value: 'facility' });
        rawConstraints.name = 'Department Library';
        confidence = 0.85;
        reason = 'recognized navigation request for library';
      } else {
        confidence = 0.65;
        ambiguity = true;
        reason = 'navigation requested without recognized destination';
      }
    }
    // Pattern D: Operational Info / Facility Query ("open", "hours", "capacity", "wifi")
    else if (
      /\b(open|hours|operational\s+hours|timing|timings)\b/i.test(cleanText) ||
      (/\b(capacity|wifi|air\s*conditioned|projector)\b/i.test(cleanText) &&
        !/\b(find|locate|where|navigate|go\s+to|take\s+me|show\s+me|search)\b/i.test(cleanText))
    ) {
      intent = 'QUERY_INFO';
      confidence = 0.80;
      if (detectedCategory) {
        rawConstraints.category = detectedCategory;
        entities.push({ type: 'category', value: detectedCategory });
      }
      if (matchedName) {
        rawConstraints.name = matchedName;
        entities.push({ type: 'room_name', value: matchedName });
      }
      reason = 'recognized facility or operational info query';
    }
    // Pattern E: Known Room Name Mention
    else if (matchedName) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'room_name', value: matchedName });
      rawConstraints.name = matchedName;
      confidence = 0.90;
      reason = `matched known room name: "${matchedName}"`;
    }
    // Pattern F: Known Alias Mention
    else if (matchedAlias) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'alias', value: matchedAlias });
      rawConstraints.alias = matchedAlias;
      confidence = 0.90;
      reason = `matched known location alias: "${matchedAlias}"`;
    }
    // Pattern G: Room Identifier Mention (e.g. "room 204", "locate room 204", "A-204")
    else if (roomIdentifier) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'room_name', value: roomIdentifier });
      rawConstraints.name = roomIdentifier;
      confidence = 0.85;
      reason = `matched room identifier: "${roomIdentifier}"`;
    }
    // Pattern H: Department Mention (e.g. "Where can I find the CSE department?")
    else if (detectedDepartment) {
      intent = 'LOCATE_ROOM';
      confidence = 0.85;
      reason = `matched department: "${detectedDepartment}"`;
    }
    // Pattern I: Category Search (e.g. "Find an accessible entrance", "Where is the elevator?")
    else if (detectedCategory) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'category', value: detectedCategory });
      rawConstraints.category = detectedCategory;
      confidence = 0.85;
      reason = `recognized location request for category: ${detectedCategory}`;
    }
    // Pattern J: Location query keywords ("where is", "find", "locate", "show me")
    else if (/\b(where\s+(?:is|can\s+i\s+find|are)|find|locate|show\s+me|search\s+for)\b/i.test(cleanText)) {
      if (/\b(library)\b/i.test(cleanText)) {
        intent = 'LOCATE_ROOM';
        entities.push({ type: 'room_name', value: 'Department Library' });
        rawConstraints.name = 'Department Library';
        confidence = 0.85;
        reason = 'recognized location request for library';
      } else {
        // Anti-overmatching: "where is the room?" or "find a room" without identifier
        intent = 'LOCATE_ROOM';
        confidence = 0.50;
        ambiguity = true;
        reason = 'location query missing specific room identifier or category';
      }
    }
    // Pattern K: Unrecognized / Off-topic
    else {
      intent = 'FALLBACK';
      confidence = 0.0;
      reason = 'unsupported or off-topic request';
    }

    // ── 4. Whitelist Constraints Enforcement ────────────────────────────────
    const sanitizedConstraints = {};
    for (const key of ALLOWED_CONSTRAINTS) {
      if (
        Object.prototype.hasOwnProperty.call(rawConstraints, key) &&
        rawConstraints[key] !== undefined &&
        rawConstraints[key] !== null
      ) {
        sanitizedConstraints[key] = rawConstraints[key];
      }
    }

    // ── 5. Deduplicate Entities ─────────────────────────────────────────────
    const seenEntities = new Set();
    const dedupedEntities = [];
    for (const ent of entities) {
      const key = `${ent.type}:${ent.value}`;
      if (!seenEntities.has(key)) {
        seenEntities.add(key);
        dedupedEntities.push(ent);
      }
    }

    return {
      intent,
      entities: dedupedEntities,
      constraints: sanitizedConstraints,
      confidence: Math.min(1.0, Math.max(0.0, confidence)),
      ambiguity,
      reason
    };
  }

  /**
   * Helper: Normalizes floor level expressions to an integer.
   * @private
   */
  _normalizeFloor(cleanText) {
    if (/\b(ground\s+floor|ground\s+level|floor\s+0)\b/i.test(cleanText)) return 0;
    if (/\b(first\s+floor|1st\s+floor|floor\s+1)\b/i.test(cleanText)) return 1;
    if (/\b(second\s+floor|2nd\s+floor|floor\s+2)\b/i.test(cleanText)) return 2;
    if (/\b(third\s+floor|3rd\s+floor|floor\s+3)\b/i.test(cleanText)) return 3;
    if (/\b(fourth\s+floor|4th\s+floor|floor\s+4)\b/i.test(cleanText)) return 4;
    if (/\b(fifth\s+floor|5th\s+floor|floor\s+5)\b/i.test(cleanText)) return 5;
    if (/\b(basement)\b/i.test(cleanText)) return -1;
    return null;
  }

  /**
   * Helper: Normalizes capacity threshold expressions to an integer.
   * @private
   */
  _normalizeCapacity(cleanText) {
    const match1 = cleanText.match(/\b(?:capacity\s*(?:above|over|exceeding|greater\s+than|at\s+least|of\s+at\s+least|more\s+than|>=?|>)\s*(\d+))\b/i);
    if (match1) return parseInt(match1[1], 10);

    const match2 = cleanText.match(/\b(?:more\s+than|over|above|at\s+least)\s+(\d+)\s*(?:seats|people|students|capacity)\b/i);
    if (match2) return parseInt(match2[1], 10);

    const match3 = cleanText.match(/\b(\d+)\s*\+\s*(?:seats|capacity|people|students)\b/i);
    if (match3) return parseInt(match3[1], 10);

    return null;
  }

  /**
   * Helper: Normalizes category keywords and synonyms.
   * @private
   */
  _normalizeCategory(cleanText) {
    if (/\b(restroom|restrooms|washroom|washrooms|toilet|toilets|lavatory|lavatories|wc)\b/i.test(cleanText)) {
      return 'restroom';
    }
    if (/\b(elevator|elevators|lift|lifts)\b/i.test(cleanText)) {
      return 'elevator';
    }
    if (/\b(lab|labs|laboratory|laboratories|computer\s+lab|software\s+lab|ai\s+lab|hardware\s+lab)\b/i.test(cleanText)) {
      return 'laboratory';
    }
    if (/\b(entrance|entrances|entry|entries|main\s+door|gate)\b/i.test(cleanText)) {
      return 'entrance';
    }
    if (/\b(stair|stairs|staircase|staircases|stairway|stairways|steps)\b/i.test(cleanText)) {
      return 'stairs';
    }
    if (/\b(classroom|classrooms|lecture\s+hall|lecture\s+room|seminar\s+hall)\b/i.test(cleanText)) {
      return 'classroom';
    }
    if (/\b(emergency\s+exit|emergency\s+exits|fire\s+exit|fire\s+exits|evacuation\s+door|fire\s+door)\b/i.test(cleanText)) {
      return 'emergency_exit';
    }
    return null;
  }

  /**
   * Helper: Normalizes department names and abbreviations.
   * @private
   */
  _normalizeDepartment(cleanText) {
    if (/\b(cse|computer\s+engineering|computer\s+science|comp\s+eng)\b/i.test(cleanText)) {
      return 'Computer Engineering';
    }
    if (/\b(it\s+dept|it\s+department|information\s+technology|info\s+tech)\b/i.test(cleanText)) {
      return 'Information Technology';
    }
    if (/\b(admin|administration|administrative)\b/i.test(cleanText)) {
      return 'Administration';
    }
    if (/\b(safety|safety\s+and\s+facilities|safety\s+&\s+facilities)\b/i.test(cleanText)) {
      return 'Safety & Facilities';
    }
    return null;
  }

  /**
   * Helper: Extracts room identifiers (e.g. "Room 204", "A-204", "Room 101").
   * Avoids bare word "room" without a room number or code.
   * @private
   */
  _normalizeRoomIdentifier(cleanText) {
    const match1 = cleanText.match(/\b(?:room|rm|classroom|hall)\s+([a-z]?\d{1,4}[a-z]?|[a-z]-\d{1,4})\b/i);
    if (match1) {
      const code = match1[1].trim();
      return `Room ${code.toUpperCase()}`;
    }
    const match2 = cleanText.match(/\b([a-z]-\d{3,4})\b/i);
    if (match2) {
      return `Room ${match2[1].toUpperCase()}`;
    }
    return null;
  }
}

module.exports = new QueryExtractorService();
