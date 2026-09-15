const semanticGraphService = require('./semantic_graph.service');

/**
 * Query Extractor Service (Owner: Surabhi)
 *
 * Deterministic, rule-based extraction layer that converts natural-language text
 * into controlled structured intents, entities, constraints, confidence scores,
 * ambiguity flags, and explainability reasons.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This service NEVER executes database, filesystem, shell, or network operations.
 * 2. It performs strictly deterministic, in-memory string parsing and extraction.
 * 3. Constraints are strictly whitelisted and typed.
 * 4. Never invents node IDs. Node resolution is left entirely to the SemanticGraphService.
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

    const rawLower = text.toLowerCase();
    const cleanText = rawLower.replace(/[^\w\s-]/g, ' ').replace(/\s+/g, ' ').trim();

    let intent = null;
    const entities = [];
    const rawConstraints = {};
    let confidence = 0.0;
    let ambiguity = false;
    let reason = 'unsupported or off-topic request';

    // ── Check Accessibility Requirement ────────────────────────────────────
    const hasAccessibleKeyword = /\b(accessible|wheelchair|step-free|stepfree|barrier-free|ramp)\b/i.test(cleanText);
    const userRequiresAccessible = userContext && userContext.accessible === true;

    if (hasAccessibleKeyword || userRequiresAccessible) {
      rawConstraints.accessible = true;
      entities.push({ type: 'accessibility', value: 'accessible' });
    }

    // ── Check Graph-backed Entities ────────────────────────────────────────
    const matchedAlias = semanticGraphService.findAliasInText(text);
    const matchedName = semanticGraphService.findNameInText(text);
    const matchedDept = semanticGraphService.findDepartmentInText(text);

    // ── Check Facility / Amenity Keywords (word-boundary safe) ─────────────
    if (/\b(wifi|wi-fi|internet)\b/i.test(cleanText)) {
      rawConstraints.facility = 'wifiZone';
      entities.push({ type: 'facility', value: 'wifiZone' });
    }
    if (/\b(projector)\b/i.test(cleanText)) {
      rawConstraints.facility = 'projectorAvailable';
      entities.push({ type: 'facility', value: 'projectorAvailable' });
    }
    if (/\b(ac|air\s*conditioned|air\s*conditioning)\b/i.test(cleanText)) {
      rawConstraints.facility = 'airConditioned';
      entities.push({ type: 'facility', value: 'airConditioned' });
    }
    if (/\b(braille)\b/i.test(cleanText)) {
      rawConstraints.facility = 'brailleButtons';
      entities.push({ type: 'facility', value: 'brailleButtons' });
    }
    if (/\b(first\s*aid|emergency\s*kit)\b/i.test(cleanText)) {
      rawConstraints.facility = 'emergencyFirstAid';
      entities.push({ type: 'facility', value: 'emergencyFirstAid' });
    }

    // ── Check Floor Keywords ───────────────────────────────────────────────
    if (/\b(first\s+floor|floor\s+1|1st\s+floor)\b/i.test(cleanText)) {
      rawConstraints.floor = 1;
      entities.push({ type: 'floor', value: '1' });
    }

    // ── Check Conflicting / Contradictory Categories ───────────────────────
    const requestedCategories = [];
    if (/\b(lab|labs|laboratory|laboratories)\b/i.test(cleanText)) {
      requestedCategories.push('laboratory');
    }
    if (/\b(exit|exits|emergency|evacuat\w*)\b/i.test(cleanText)) {
      requestedCategories.push('emergency_exit');
    }
    if (/\b(lift|lifts|elevator|elevators)\b/i.test(cleanText)) {
      requestedCategories.push('elevator');
    }
    if (/\b(restroom|restrooms|toilet|toilets|washroom|washrooms)\b/i.test(cleanText)) {
      requestedCategories.push('restroom');
    }

    if (requestedCategories.length > 1) {
      // Contradictory request asking for multiple disparate categories at once
      return {
        intent: 'FALLBACK',
        entities: requestedCategories.map(c => ({ type: 'category', value: c })),
        constraints: {},
        confidence: 0.40,
        ambiguity: true,
        reason: 'contradictory or multiple conflicting destination categories in query'
      };
    }

    // ── Intent Extraction Logic ────────────────────────────────────────────

    // Pattern 1: Emergency Exit Request
    if (/\b(exit|exits|emergency|evacuat\w*)\b/i.test(cleanText)) {
      intent = 'EMERGENCY_EXIT';
      entities.push({ type: 'category', value: 'emergency_exit' });
      rawConstraints.category = 'emergency_exit';
      confidence = 0.90;
      reason = 'recognized emergency exit category';
    }
    // Pattern 2: Nearest / Closest Request
    else if (/\b(nearest|closest)\b/i.test(cleanText)) {
      if (/\b(lab|labs|laboratory|laboratories)\b/i.test(cleanText)) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'category', value: 'laboratory' });
        rawConstraints.category = 'laboratory';
        confidence = 0.85;
        reason = 'recognized nearest laboratory request';
      } else if (/\b(lift|lifts|elevator|elevators)\b/i.test(cleanText)) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'category', value: 'elevator' });
        rawConstraints.category = 'elevator';
        confidence = 0.85;
        reason = 'recognized nearest elevator request';
      } else if (/\b(restroom|restrooms|toilet|toilets|washroom|washrooms)\b/i.test(cleanText)) {
        intent = 'FIND_NEAREST';
        entities.push({ type: 'category', value: 'restroom' });
        rawConstraints.category = 'restroom';
        confidence = 0.80;
        reason = 'recognized nearest restroom request';
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
      } else {
        // "nearest" keyword present but destination missing
        intent = 'FALLBACK';
        confidence = 0.30;
        ambiguity = true;
        reason = 'nearest keyword present but no target destination specified';
      }
    }
    // Pattern 3: Navigation Request ("take me", "navigate", "go to", "route to")
    else if (/\b(take\s+me|navigate|go\s+to|route\s+to|directions\s+to)\b/i.test(cleanText)) {
      intent = 'NAVIGATE_TO';
      if (matchedAlias) {
        entities.push({ type: 'alias', value: matchedAlias });
        rawConstraints.alias = matchedAlias;
        confidence = 0.85;
        reason = 'recognized navigation request for known alias';
      } else if (matchedName) {
        entities.push({ type: 'room_name', value: matchedName });
        rawConstraints.name = matchedName;
        confidence = 0.85;
        reason = 'recognized navigation request for known room name';
      } else if (/\b(lab|labs|laboratory|laboratories)\b/i.test(cleanText)) {
        entities.push({ type: 'category', value: 'laboratory' });
        rawConstraints.category = 'laboratory';
        confidence = 0.80;
        reason = 'recognized navigation request for laboratory';
      } else if (/\b(library)\b/i.test(cleanText)) {
        entities.push({ type: 'category', value: 'facility' });
        rawConstraints.name = 'Department Library';
        confidence = 0.80;
        reason = 'recognized navigation request for library';
      } else {
        confidence = 0.65;
        ambiguity = true;
        reason = 'navigation requested without recognized destination';
      }
    }
    // Pattern 4: Known Alias Mention (without explicit navigate/nearest verb)
    else if (matchedAlias) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'alias', value: matchedAlias });
      rawConstraints.alias = matchedAlias;
      confidence = 0.85;
      reason = `matched known location alias: "${matchedAlias}"`;
    }
    // Pattern 5: Known Room Name Mention
    else if (matchedName) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'room_name', value: matchedName });
      rawConstraints.name = matchedName;
      confidence = 0.85;
      reason = `matched known room name: "${matchedName}"`;
    }
    // Pattern 6: Known Department Mention
    else if (matchedDept) {
      intent = 'LOCATE_ROOM';
      entities.push({ type: 'department', value: matchedDept });
      rawConstraints.department = matchedDept;
      confidence = 0.75;
      reason = `matched known department: "${matchedDept}"`;
    }
    // Pattern 7: Location Request ("where is", "find", "locate", "show me")
    else if (/\b(where\s+is|find|locate|show\s+me)\b/i.test(cleanText)) {
      if (/\b(lab|labs|laboratory|laboratories)\b/i.test(cleanText)) {
        intent = 'LOCATE_ROOM';
        entities.push({ type: 'category', value: 'laboratory' });
        rawConstraints.category = 'laboratory';
        confidence = 0.80;
        reason = 'recognized location request for laboratory';
      } else if (/\b(lift|lifts|elevator|elevators)\b/i.test(cleanText)) {
        intent = 'LOCATE_ROOM';
        entities.push({ type: 'category', value: 'elevator' });
        rawConstraints.category = 'elevator';
        confidence = 0.80;
        reason = 'recognized location request for elevator';
      } else if (/\b(library)\b/i.test(cleanText)) {
        intent = 'LOCATE_ROOM';
        entities.push({ type: 'room_name', value: 'Department Library' });
        rawConstraints.name = 'Department Library';
        confidence = 0.80;
        reason = 'recognized location request for library';
      } else {
        intent = 'LOCATE_ROOM';
        confidence = 0.60;
        ambiguity = true;
        reason = 'location query missing destination name or category';
      }
    }
    // Pattern 8: Facility / Amenity Info Query
    else if (/\b(open|hours|capacity|wifi|air\s*conditioned|projector)\b/i.test(cleanText)) {
      intent = 'QUERY_INFO';
      confidence = 0.70;
      reason = 'recognized facility or operational info query';
    }
    // Pattern 9: Unrecognized / Off-topic
    else {
      intent = 'FALLBACK';
      confidence = 0.0;
      reason = 'unsupported or off-topic request';
    }

    // ── Sanitize Constraints (Whitelist enforcement) ───────────────────────
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

    // Deduplicate entities
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
}

module.exports = new QueryExtractorService();
