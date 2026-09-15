const { validateContract } = require('../../utils/schema_validator');

/**
 * AI & Semantic Knowledge Graph Controller (Owner: Surabhi)
 * Converts natural-language user requests into validated structured graph queries.
 *
 * CRITICAL SECURITY INVARIANT:
 * This controller never executes arbitrary SQL or raw database mutations.
 * It produces validated structured intents and constraints conforming to
 * contracts/ai-response.schema.json.
 *
 * All outgoing responses are validated against ai-response.schema.json before
 * being sent to the client. An invalid internal response triggers HTTP 500, not
 * a forward of the bad payload.
 */

/**
 * Minimum confidence score required to emit a non-FALLBACK intent.
 * Queries that do not match any supported intent pattern fall below this
 * threshold and are always returned as FALLBACK.
 */
const CONFIDENCE_THRESHOLD = 0.5;

/**
 * The safe FALLBACK response emitted whenever:
 *  - no intent pattern matched, or
 *  - confidence is below CONFIDENCE_THRESHOLD, or
 *  - the assembled payload fails ai-response schema validation.
 *
 * targetNodeId is always null for FALLBACK — no destination is claimed.
 */
function buildFallbackPayload(text) {
  return {
    intent: 'FALLBACK',
    entities: [],
    constraints: {},
    targetNodeId: null,
    confidence: 0.0,
    responseMessage:
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

      // ── Intent / entity / constraint extraction (rule-based placeholder) ─
      // Full SLM inference pipeline will be developed by Surabhi in
      // feature/surabhi-semantic-ai. This rule-based layer provides a safe,
      // deterministic baseline that satisfies the contract.
      let intent = null;
      let entities = [];
      let constraints = {};
      let targetNodeId = null;
      let confidence = 0.0;
      let responseMessage = null;

      if (lower.includes('nearest') || lower.includes('closest')) {
        if (lower.includes('lab') || lower.includes('laboratory')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'laboratory' }];
          constraints.category = 'laboratory';
          confidence = 0.80;
          responseMessage =
            'Looking for the nearest laboratory. Please confirm your current location.';
        } else if (lower.includes('exit') || lower.includes('emergency')) {
          intent = 'EMERGENCY_EXIT';
          entities = [{ type: 'category', value: 'emergency_exit' }];
          confidence = 0.90;
          responseMessage =
            'Locating the nearest emergency exit. Please follow the highlighted route.';
        } else if (lower.includes('lift') || lower.includes('elevator')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'elevator' }];
          constraints.category = 'elevator';
          confidence = 0.80;
          responseMessage =
            'Looking for the nearest elevator. Please confirm your current location.';
        } else if (lower.includes('restroom') || lower.includes('toilet') || lower.includes('washroom')) {
          intent = 'FIND_NEAREST';
          entities = [{ type: 'category', value: 'restroom' }];
          constraints.category = 'restroom';
          confidence = 0.80;
          responseMessage =
            'Looking for the nearest restroom. Please confirm your current location.';
        } else {
          // "nearest" keyword present but target unrecognised — below threshold
          intent = 'FALLBACK';
          confidence = 0.30;
        }
      } else if (lower.includes('exit') || lower.includes('emergency') || lower.includes('evacuat')) {
        intent = 'EMERGENCY_EXIT';
        entities = [{ type: 'category', value: 'emergency_exit' }];
        confidence = 0.90;
        responseMessage =
          'Locating the nearest emergency exit. Please follow the highlighted route.';
      } else if (lower.includes('go to') || lower.includes('take me to') || lower.includes('navigate to')) {
        intent = 'NAVIGATE_TO';
        confidence = 0.65;
        responseMessage =
          'Navigation requested. Please confirm your destination from the map.';
      } else if (lower.includes('where is') || lower.includes('find') || lower.includes('locate')) {
        intent = 'LOCATE_ROOM';
        confidence = 0.60;
        responseMessage =
          'Searching for the location. Please provide more detail if possible.';
      } else if (lower.includes('open') || lower.includes('hours') || lower.includes('capacity') || lower.includes('wifi')) {
        intent = 'QUERY_INFO';
        confidence = 0.65;
        responseMessage =
          'Looking up facility information. Please specify a room or area name.';
      }

      // Propagate accessibility constraint from user context
      if (userContext && userContext.accessible === true) {
        constraints.accessible = true;
      }

      // ── Confidence gate — demote to FALLBACK if below threshold ─────────
      if (intent === null || intent === 'FALLBACK' || confidence < CONFIDENCE_THRESHOLD) {
        const fallback = buildFallbackPayload(text);
        // Validate the fallback payload itself before sending
        const fallbackValidation = validateContract('ai-response', fallback);
        if (!fallbackValidation.valid) {
          // This should never happen — the fallback shape is statically defined
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
