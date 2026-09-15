const { validateContract } = require('../../utils/schema_validator');
const semanticGraphService = require('./semantic_graph.service');

/**
 * AI & Semantic Knowledge Graph Controller (Owner: Surabhi)
 * Converts natural-language user requests into validated structured graph queries.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This controller NEVER executes arbitrary SQL or raw database mutations.
 * 2. It resolves semantic constraints deterministically using SemanticGraphService.
 * 3. It never invents destination node IDs or selects arbitrary candidates.
 * 4. All outgoing responses are validated against contracts/ai-response.schema.json
 *    before being returned to the client. Schema violation returns HTTP 500.
 */

/**
 * Minimum confidence score required to emit a non-FALLBACK intent.
 */
const CONFIDENCE_THRESHOLD = 0.5;

/**
 * The safe FALLBACK response emitted whenever:
 *  - no intent pattern matched, or
 *  - confidence is below CONFIDENCE_THRESHOLD, or
 *  - constraint resolution finds zero matches, or
 *  - constraint resolution is ambiguous (multiple matches), or
 *  - the assembled payload fails ai-response schema validation.
 *
 * targetNodeId is always null for FALLBACK — no destination is claimed.
 *
 * @param {string} [customMessage]
 * @param {number} [customConfidence]
 * @param {object} [constraints]
 * @returns {object}
 */
function buildFallbackPayload(customMessage, customConfidence = 0.0, constraints = {}) {
  return {
    intent: 'FALLBACK',
    entities: [],
    constraints: constraints && typeof constraints === 'object' ? constraints : {},
    targetNodeId: null,
    confidence: customConfidence,
    responseMessage:
      customMessage ||
      'I could not understand that request. Please rephrase — ' +
      'you can ask me to find rooms, labs, elevators, or emergency exits.'
  };
}

class AiController {
  async processQuery(req, res, next) {
    try {
      // ── Input validation ────────────────────────────────────────────────
      const inputValidation = validateContract('ai-query', req.body);
      if (!inputValidation.valid) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Invalid AiQuery schema',
            details: inputValidation.errors
          }
        });
      }

      const { text, buildingId, userContext } = req.body;
      const lower = text.toLowerCase();

      // ── Intent / entity / constraint extraction ─────────────────────────
      let intent = null;
      let entities = [];
      let constraints = {};
      let targetNodeId = null;
      let confidence = 0.0;
      let responseMessage = null;

      // Extract dataset-derived semantic entities if present in text
      const matchedAlias = semanticGraphService.findAliasInText(text);
      const matchedName = semanticGraphService.findNameInText(text);
      const matchedDept = semanticGraphService.findDepartmentInText(text);

      if (lower.includes('nearest') || lower.includes('closest')) {
        if (lower.includes('lab') || lower.includes('laboratory')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'laboratory' }];
          constraints.category = 'laboratory';
          confidence = 0.80;
        } else if (lower.includes('exit') || lower.includes('emergency') || lower.includes('evacuat')) {
          intent = 'EMERGENCY_EXIT';
          entities = [{ type: 'category', value: 'emergency_exit' }];
          constraints.category = 'emergency_exit';
          confidence = 0.90;
        } else if (lower.includes('lift') || lower.includes('elevator')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'elevator' }];
          constraints.category = 'elevator';
          confidence = 0.80;
        } else if (lower.includes('restroom') || lower.includes('toilet') || lower.includes('washroom')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'restroom' }];
          constraints.category = 'restroom';
          confidence = 0.80;
        } else if (matchedAlias) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'alias', value: matchedAlias }];
          constraints.alias = matchedAlias;
          confidence = 0.85;
        } else if (matchedName) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'room_name', value: matchedName }];
          constraints.name = matchedName;
          confidence = 0.85;
        } else {
          // "nearest" keyword present but target unrecognised — below threshold
          intent = 'FALLBACK';
          confidence = 0.30;
        }
      } else if (lower.includes('exit') || lower.includes('emergency') || lower.includes('evacuat')) {
        intent = 'EMERGENCY_EXIT';
        entities = [{ type: 'category', value: 'emergency_exit' }];
        constraints.category = 'emergency_exit';
        confidence = 0.90;
      } else if (matchedAlias) {
        // Alias-based query recognition
        if (lower.includes('go to') || lower.includes('take me to') || lower.includes('navigate to')) {
          intent = 'NAVIGATE_TO';
        } else {
          intent = 'LOCATE_ROOM';
        }
        entities = [{ type: 'alias', value: matchedAlias }];
        constraints.alias = matchedAlias;
        confidence = 0.85;
      } else if (matchedName) {
        // Room name-based query recognition
        if (lower.includes('go to') || lower.includes('take me to') || lower.includes('navigate to')) {
          intent = 'NAVIGATE_TO';
        } else {
          intent = 'LOCATE_ROOM';
        }
        entities = [{ type: 'room_name', value: matchedName }];
        constraints.name = matchedName;
        confidence = 0.85;
      } else if (matchedDept) {
        // Department-based query recognition
        intent = 'LOCATE_ROOM';
        entities = [{ type: 'department', value: matchedDept }];
        constraints.department = matchedDept;
        confidence = 0.75;
      } else if (lower.includes('go to') || lower.includes('take me to') || lower.includes('navigate to')) {
        intent = 'NAVIGATE_TO';
        confidence = 0.65;
        responseMessage = 'Navigation requested. Please confirm your destination from the map.';
      } else if (lower.includes('where is') || lower.includes('find') || lower.includes('locate')) {
        intent = 'LOCATE_ROOM';
        confidence = 0.60;
        responseMessage = 'Searching for the location. Please provide more detail if possible.';
      } else if (lower.includes('open') || lower.includes('hours') || lower.includes('capacity') || lower.includes('wifi')) {
        intent = 'QUERY_INFO';
        confidence = 0.65;
        if (lower.includes('wifi')) {
          constraints.facility = 'wifiZone';
        }
        responseMessage = 'Looking up facility information. Please specify a room or area name.';
      }

      // Propagate accessibility constraint from user context or query text
      if (
        (userContext && userContext.accessible === true) ||
        lower.includes('accessible') ||
        lower.includes('wheelchair')
      ) {
        constraints.accessible = true;
      }

      // ── Confidence gate — demote to FALLBACK if below threshold ─────────
      if (intent === null || intent === 'FALLBACK' || confidence < CONFIDENCE_THRESHOLD) {
        const fallback = buildFallbackPayload();
        const fallbackValidation = validateContract('ai-response', fallback);
        if (!fallbackValidation.valid) {
          return res.status(500).json({
            error: {
              code: 'AI_RESPONSE_VALIDATION_FAILED',
              message: 'Internal error: fallback response failed schema validation.',
              details: fallbackValidation.errors
            }
          });
        }
        return res.status(200).json(fallback);
      }

      // ── Semantic Graph Resolution ───────────────────────────────────────
      // If structured constraints were derived, resolve candidates via SemanticGraphService
      if (Object.keys(constraints).length > 0) {
        const resolution = semanticGraphService.resolveCandidates(constraints);

        if (resolution.status === 'resolved') {
          // Exactly one candidate matched
          targetNodeId = resolution.candidateIds[0];
          const candidate = resolution.candidates[0];

          if (intent === 'EMERGENCY_EXIT') {
            responseMessage = `Emergency exit located (${candidate.name}). Please follow the highlighted route.`;
          } else if (intent === 'FIND_NEAREST') {
            responseMessage = `Nearest ${candidate.category} located (${candidate.name}). Please confirm your current location.`;
          } else if (intent === 'NAVIGATE_TO') {
            responseMessage = `Destination found: ${candidate.name}. Confirm your route on the map.`;
          } else if (intent === 'LOCATE_ROOM') {
            responseMessage = `Located ${candidate.name} on ${candidate.floorName || 'Floor 1'}.`;
          } else if (intent === 'QUERY_INFO') {
            responseMessage = `Facility info for ${candidate.name}: ${candidate.description || 'Information available on map.'}`;
          } else {
            responseMessage = `Found ${candidate.name}.`;
          }
        } else if (resolution.status === 'ambiguous') {
          // Multiple candidates match: safe ambiguity fallback
          intent = 'FALLBACK';
          targetNodeId = null;
          confidence = 0.50;
          const candidateNames = resolution.candidates.map(c => c.name).join(', ');
          responseMessage = `Multiple matching locations found (${candidateNames}). Please specify which one you are looking for.`;
        } else {
          // Zero candidates matched: safe not_found fallback
          intent = 'FALLBACK';
          targetNodeId = null;
          confidence = 0.0;
          responseMessage = 'No matching location found for the specified criteria. Please rephrase or check the building map.';
        }
      }

      // ── Assemble response payload ────────────────────────────────────────
      const responsePayload = {
        intent,
        entities,
        constraints,
        targetNodeId,
        confidence,
        responseMessage
      };

      // ── Output validation — MUST pass before sending to client ───────────
      const outputValidation = validateContract('ai-response', responsePayload);
      if (!outputValidation.valid) {
        return res.status(500).json({
          error: {
            code: 'AI_RESPONSE_VALIDATION_FAILED',
            message: 'Internal error: assembled AI response failed schema validation.',
            details: outputValidation.errors
          }
        });
      }

      return res.status(200).json(responsePayload);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiController();
